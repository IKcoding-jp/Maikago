// Firestore Streamの購読、楽観的更新との競合回避、バッチ更新制御
import 'dart:async';
import 'dart:math' as math;
import 'package:maikago/services/data_service.dart';
import 'package:maikago/models/list.dart';
import 'package:maikago/models/shop.dart';
import 'package:maikago/providers/data_provider_state.dart';
import 'package:maikago/providers/managers/data_cache_manager.dart';
import 'package:maikago/providers/managers/pending_update_policy.dart';
import 'package:maikago/providers/repositories/item_repository.dart';
import 'package:maikago/providers/repositories/shop_repository.dart';
import 'package:maikago/services/debug_service.dart';

/// リアルタイム同期とバッチ更新制御を管理するクラス。
/// - Firestore Streamの購読（items/shops）
/// - 楽観的更新との競合回避（バウンス抑止）
/// - バッチ更新中の同期スキップ
class RealtimeSyncManager {
  RealtimeSyncManager({
    required DataService dataService,
    required DataCacheManager cacheManager,
    required ItemRepository itemRepository,
    required ShopRepository shopRepository,
    required DataProviderState state,
  })  : _dataService = dataService,
        _cacheManager = cacheManager,
        _itemRepository = itemRepository,
        _shopRepository = shopRepository,
        _state = state;

  final DataService _dataService;
  final DataCacheManager _cacheManager;
  final ItemRepository _itemRepository;
  final ShopRepository _shopRepository;
  final DataProviderState _state;

  // リアルタイム同期用の購読
  StreamSubscription<List<ListItem>>? _itemsSubscription;
  StreamSubscription<List<Shop>>? _shopsSubscription;

  // 購読状態追跡
  bool _isSubscriptionActive = false;

  // リトライ制御
  int _retryCount = 0;
  static const int _maxRetries = 5;
  Timer? _retryTimer;

  // バウンス抑止ポリシー（書き込み完了ベース・issue #160）
  static const PendingUpdatePolicy _policy = PendingUpdatePolicy();

  /// リアルタイム購読がアクティブかどうか
  bool get isSubscriptionActive => _isSubscriptionActive;

  // --- バッチ更新制御 ---

  /// バッチ更新を実行（notifyListeners抑制付き）
  Future<T> runBatchUpdate<T>(Future<T> Function() operation) async {
    _state.isBatchUpdating = true;
    try {
      return await operation();
    } finally {
      _state.isBatchUpdating = false;
      _state.notifyListeners();
    }
  }

  // --- リアルタイム同期 ---

  /// リアルタイム同期の開始（items/shops を購読）
  void startRealtimeSync() {
    // すでに購読している場合は一旦解除
    cancelRealtimeSync();

    // ローカルモードの場合は同期をスキップ
    if (_cacheManager.isLocalMode) {
      return;
    }

    try {
      _itemsSubscription = _dataService
          .getItems(isAnonymous: _state.shouldUseAnonymousSession)
          .listen(
        (remoteItems) {
          _resetRetryCount();

          // バッチ更新中はリアルタイム同期を完全に無視
          if (_state.isBatchUpdating) return;

          // 直前にローカルが更新したアイテムは書き込み完了まで（＋配信遅延ぶん）
          // ローカル版を優先する（issue #160）。
          final merged = _mergeWithProtection<ListItem>(
            remote: remoteItems,
            local: _cacheManager.items,
            idOf: (i) => i.id,
            pendingUpdates: _itemRepository.pendingUpdates,
            inFlightUpdates: _itemRepository.inFlightUpdates,
          );

          _cacheManager.updateItems(merged);
          _cacheManager.associateItemsWithShops();
          _cacheManager.removeDuplicateItems();
          _state.isSynced = true;
          _state.notifyListeners();
        },
        onError: (error) {
          DebugService().logError('リスト同期エラー: $error');
          _onSubscriptionError();
        },
        onDone: () {
          _onSubscriptionError();
        },
      );

      _shopsSubscription = _dataService
          .getShops(isAnonymous: _state.shouldUseAnonymousSession)
          .listen(
        (remoteShops) {
          _resetRetryCount();

          // バッチ更新中はリアルタイム同期を完全に無視
          if (_state.isBatchUpdating) return;

          // 直前にローカルが更新したショップは書き込み完了まで（＋配信遅延ぶん）
          // ローカル版を優先する（issue #160）。
          final merged = _mergeWithProtection<Shop>(
            remote: remoteShops,
            local: _cacheManager.shops,
            idOf: (s) => s.id,
            pendingUpdates: _shopRepository.pendingUpdates,
            inFlightUpdates: _shopRepository.inFlightUpdates,
          );

          _cacheManager.updateShops(merged);
          _cacheManager.removeDuplicateShops();
          _cacheManager.associateItemsWithShops();
          _cacheManager.removeDuplicateItems();
          _state.isSynced = true;
          _state.notifyListeners();
        },
        onError: (error) {
          DebugService().logError('ショップ同期エラー: $error');
          _onSubscriptionError();
        },
        onDone: () {
          _onSubscriptionError();
        },
      );

      _isSubscriptionActive = true;
      _resetRetryCount();
      DebugService().logInfo('リアルタイム同期開始完了');
    } catch (e) {
      _isSubscriptionActive = false;
      DebugService().logError('リアルタイム同期開始エラー: $e');
      _scheduleRetry();
    }
  }

  /// リモートスナップショットを、保護中（書き込み中＋配信遅延窓）のローカル値を
  /// 残しつつマージする。items/shops 共通処理（issue #160）。
  ///
  /// 副作用として、保護が切れた保留（pendingUpdates / inFlightUpdates）を
  /// クリーンアップする。
  List<T> _mergeWithProtection<T>({
    required List<T> remote,
    required List<T> local,
    required String Function(T) idOf,
    required Map<String, DateTime> pendingUpdates,
    required Set<String> inFlightUpdates,
  }) {
    final now = DateTime.now();
    bool isProtected(String id) => _policy.isProtected(
          markedAt: pendingUpdates[id],
          inFlight: inFlightUpdates.contains(id),
          now: now,
        );

    // 保護が切れた保留をクリーンアップ（pending と in-flight の両方）
    for (final id in pendingUpdates.keys.toList()) {
      if (!isProtected(id)) {
        pendingUpdates.remove(id);
        inFlightUpdates.remove(id);
      }
    }

    return mergePreferringProtectedLocal<T>(
      remote: remote,
      local: local,
      idOf: idOf,
      isProtected: isProtected,
    );
  }

  /// リアルタイム同期の停止
  void cancelRealtimeSync() {
    _retryTimer?.cancel();
    _retryTimer = null;

    _itemsSubscription?.cancel();
    _itemsSubscription = null;

    _shopsSubscription?.cancel();
    _shopsSubscription = null;

    _isSubscriptionActive = false;
  }

  // --- リトライ制御 ---

  /// 購読エラーまたはストリーム終了時の処理
  void _onSubscriptionError() {
    _isSubscriptionActive = false;
    _state.isSynced = false;
    _scheduleRetry();
  }

  /// 指数バックオフ付き自動再購読をスケジュール
  void _scheduleRetry() {
    if (_retryTimer != null) return; // 既にリトライ待機中
    if (_cacheManager.isLocalMode) return; // ローカルモードではリトライしない

    if (_retryCount >= _maxRetries) {
      DebugService().logWarning('リアルタイム同期: 最大リトライ回数($_maxRetries)に到達。手動再接続が必要');
      return;
    }

    final delaySec = math.min(math.pow(2, _retryCount).toInt(), 300);
    _retryCount++;
    DebugService()
        .logWarning('リアルタイム同期: $delaySec秒後にリトライ ($_retryCount/$_maxRetries)');

    _retryTimer = Timer(Duration(seconds: delaySec), () {
      _retryTimer = null;
      if (!_cacheManager.isLocalMode) {
        startRealtimeSync();
      }
    });
  }

  /// リトライカウントをリセット（正常受信時）
  void _resetRetryCount() {
    _retryCount = 0;
    _retryTimer?.cancel();
    _retryTimer = null;
  }
}
