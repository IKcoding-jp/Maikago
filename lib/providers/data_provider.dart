// アプリの業務ロジック（一覧/編集/同期/共有合計）を集約し、UI層に通知
import 'package:maikago/services/data_service.dart';
import 'package:maikago/models/list.dart';
import 'package:maikago/models/shop.dart';
import 'package:maikago/models/sort_mode.dart';
import 'package:maikago/models/migration_result.dart';
import 'package:maikago/providers/auth_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:maikago/providers/data_provider_state.dart';
import 'package:maikago/providers/managers/data_cache_manager.dart';
import 'package:maikago/providers/managers/realtime_sync_manager.dart';
import 'package:maikago/providers/managers/shared_tab_manager.dart';
import 'package:maikago/providers/repositories/item_repository.dart';
import 'package:maikago/providers/repositories/shop_repository.dart';
import 'package:maikago/services/debug_service.dart';
import 'package:maikago/services/settings_persistence.dart';

/// データの状態管理と同期を担う Provider（ファサード）。
/// 各責務を専用クラスに委譲し、外部インターフェースを維持する。
class DataProvider extends ChangeNotifier {
  DataProvider({
    DataService? dataService,
  }) : _dataService = dataService ?? DataService() {
    _state = DataProviderState(
      notifyListeners: () => notifyListeners(),
    );
    _cacheManager = DataCacheManager(
      dataService: _dataService,
      state: _state,
    );
    _itemRepository = ItemRepository(
      dataService: _dataService,
      cacheManager: _cacheManager,
      state: _state,
    );
    _shopRepository = ShopRepository(
      dataService: _dataService,
      cacheManager: _cacheManager,
      state: _state,
    );
    _syncManager = RealtimeSyncManager(
      dataService: _dataService,
      cacheManager: _cacheManager,
      itemRepository: _itemRepository,
      shopRepository: _shopRepository,
      state: _state,
    );
    _sharedTabManager = SharedTabManager(
      dataService: _dataService,
      cacheManager: _cacheManager,
      shopRepository: _shopRepository,
      state: _state,
    );
  }

  final DataService _dataService;
  late final DataProviderState _state;
  late final DataCacheManager _cacheManager;
  late final ItemRepository _itemRepository;
  late final ShopRepository _shopRepository;
  late final RealtimeSyncManager _syncManager;
  late final SharedTabManager _sharedTabManager;

  AuthProvider? _authProvider;
  VoidCallback? _authListener;

  bool _isLoading = false;

  /// ゲストデータ移行の二重実行ガード（同時呼び出しで重複作成しないように）
  bool _isMigrating = false;

  // --- 認証連携 ---

  void setAuthProvider(AuthProvider authProvider) {
    if (_authProvider == authProvider) return;

    if (_authListener != null) {
      _authProvider?.removeListener(_authListener!);
      _authListener = null;
    }

    _authProvider = authProvider;
    _syncAuthState();

    // ゲスト→ログイン時のデータマイグレーションコールバックを設定
    authProvider.setGuestDataMigrationCallback(() => migrateGuestDataToCloud());

    _authListener = () {
      _syncAuthState();

      if (authProvider.isLoggedIn) {
        DebugService().logInfo('ログイン検出: データを完全にリセットして再読み込みします');
        if (!_isLoading) {
          _resetDataForLogin();
          _loadDataAndRecoverGuestData();
        }
      } else if (authProvider.isGuestMode) {
        DebugService().logInfo('ゲストモード検出: ローカルモードでデータを初期化');
        _initGuestMode();
      } else {
        DebugService().logInfo('ログアウト検出: データをクリアしてローカルモードに切り替え');
        clearData();
      }
    };

    authProvider.addListener(_authListener!);

    // リスナー登録前にnotifyListenersが発火済みの場合に備え、
    // 現在の認証状態に基づいてデータを読み込む
    if (authProvider.isLoggedIn && !authProvider.isLoading && !_isLoading) {
      _resetDataForLogin();
      _loadDataAndRecoverGuestData();
    } else if (authProvider.isGuestMode) {
      // アプリ起動時の復元: データクリアせずloadDataでローカルストレージから復元
      _initGuestMode(isRestoredSession: true);
    }
  }

  /// ログイン時のデータ読み込み後、移行し残したゲストデータがあれば自動救済する。
  /// 残データが無ければ [retryPendingGuestMigration] は即座に終了する（Issue #154）。
  ///
  /// 明示サインイン経路（auth_provider.signInWithGoogle）でも移行が走るため、
  /// 新規サインイン時はこのリトライと二重に起動しうるが、移行は冪等かつ
  /// [_guardedMigrate] で直列化されるため安全（残データ無しなら即終了）。
  /// このリトライはアプリ再起動でセッション復元したときの救済が主目的。
  /// loadData() が失敗してもリトライ救済を試みられるよう then ではなく
  /// whenComplete で繋ぐ。
  void _loadDataAndRecoverGuestData() {
    loadData().whenComplete(() {
      // 残ったゲストデータの再移行。失敗してもログインは継続する。
      retryPendingGuestMigration();
    });
  }

  void _resetDataForLogin() {
    _syncManager.cancelRealtimeSync();

    _cacheManager.clearData();
    _cacheManager.clearLastSyncTime();
    _itemRepository.pendingUpdates.clear();

    _state.isSynced = false;
    _cacheManager.setLocalMode(false);

    notifyListeners();
  }

  /// ゲストモード用の初期化（ローカルモードでデフォルトショップを用意）
  /// [isRestoredSession] が true の場合はデータクリアせず、ローカルストレージから復元する
  Future<void> _initGuestMode({bool isRestoredSession = false}) async {
    _cacheManager.setLocalMode(true);
    _syncManager.cancelRealtimeSync();

    if (!isRestoredSession) {
      // 新規ゲストセッション: データをクリアして新規開始
      _cacheManager.clearData();
    }

    _state.isSynced = true;
    await _shopRepository.ensureDefaultShop();
    _cacheManager.associateItemsWithShops();
    notifyListeners();
  }

  void _syncAuthState() {
    final isGuest = _authProvider?.isGuestMode ?? false;
    final isLoggedIn = _authProvider?.isLoggedIn ?? false;
    _state.shouldUseAnonymousSession = !isLoggedIn && !isGuest;
  }

  // --- Getter ---

  List<ListItem> get items => _cacheManager.items;
  List<Shop> get shops => _cacheManager.shops;
  bool get isLoading => _isLoading;
  bool get isSynced => _state.isSynced;
  bool get isLocalMode => _cacheManager.isLocalMode;

  void setLocalMode(bool isLocal) {
    _cacheManager.setLocalMode(isLocal);
    if (isLocal) {
      _syncManager.cancelRealtimeSync();
      _state.isSynced = true;
    }
    notifyListeners();
  }

  // --- アイテム操作（ItemRepositoryに委譲） ---

  Future<void> addItem(ListItem item) async {
    await _itemRepository.addItem(item);
  }

  Future<void> updateItem(ListItem item) async {
    await _itemRepository.updateItem(item);
  }

  Future<void> updateItemsBatch(List<ListItem> items) async {
    await _syncManager.runBatchUpdate(() async {
      await _itemRepository.updateItemsBatch(
        items,
        pendingShopUpdates: _shopRepository.pendingUpdates,
      );
    });
  }

  Future<void> reorderItems(
      Shop updatedShop, List<ListItem> updatedItems) async {
    // 1. キャッシュを即座に更新（同期）
    _itemRepository.applyReorderToCache(
      updatedShop,
      updatedItems,
      pendingShopUpdates: _shopRepository.pendingUpdates,
    );

    // 2. UI即時反映（isBatchUpdating前なのでオーバーライドにブロックされない）
    super.notifyListeners();

    // 3. Firebase書き込みはバッチ更新で実行（リアルタイム同期の競合を防止）
    await _syncManager.runBatchUpdate(() async {
      await _itemRepository.persistReorderToFirebase(
        updatedShop,
        updatedItems,
      );
    });
  }

  Future<void> deleteItem(String itemId) async {
    await _itemRepository.deleteItem(itemId);
  }

  Future<void> deleteItems(List<String> itemIds) async {
    await _itemRepository.deleteItems(itemIds);
  }

  // --- ショップ操作（ShopRepositoryに委譲） ---

  Future<void> addShop(Shop shop) async {
    await _shopRepository.addShop(shop);
  }

  Future<void> updateShop(Shop shop) async {
    await _shopRepository.updateShop(shop);
  }

  Future<void> deleteShop(String shopId) async {
    await _shopRepository.deleteShop(shopId);
  }

  void updateShopName(int index, String newName) {
    _shopRepository.updateShopName(index, newName);
  }

  void updateShopBudget(int index, int? budget) {
    _shopRepository.updateShopBudget(index, budget);
  }

  void clearAllItems(int shopIndex) {
    _shopRepository.clearAllItems(shopIndex);
  }

  void updateSortMode(int shopIndex, SortMode sortMode, bool isIncomplete) {
    _shopRepository.updateSortMode(shopIndex, sortMode, isIncomplete);
  }

  // --- データロード ---

  Future<void> loadData() async {
    bool shouldForceReload = false;

    if (_authProvider != null) {
      if (_cacheManager.lastSyncTime != null) {
        shouldForceReload = true;
      }
    }

    _setLoading(true);

    try {
      await _cacheManager.loadData(forceReload: shouldForceReload);

      await _shopRepository.ensureDefaultShop();

      _cacheManager.removeDuplicateShops();
      _cacheManager.associateItemsWithShops();
      _cacheManager.removeDuplicateItems();

      if (!_cacheManager.isLocalMode) {
        if (!_syncManager.isSubscriptionActive) {
          _syncManager.startRealtimeSync();
        }
      }

      _state.isSynced = true;
      DebugService().logInfo(
          'データ読み込み完了: アイテム${_cacheManager.items.length}件、ショップ${_cacheManager.shops.length}件');
    } catch (e) {
      DebugService().logError('データ読み込みエラー: $e');
      _state.isSynced = false;

      try {
        await _shopRepository.ensureDefaultShop();
      } catch (ensureError) {
        DebugService().logError('デフォルトショップ確保エラー: $ensureError');
      }
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  Future<void> checkSyncStatus() async {
    if (_cacheManager.isLocalMode) {
      _state.isSynced = true;
      notifyListeners();
      return;
    }

    try {
      _state.isSynced = await _dataService.isDataSynced();
      notifyListeners();
    } catch (e) {
      DebugService().logError('同期状態チェックエラー: $e');
      _state.isSynced = false;
      notifyListeners();
    }
  }

  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  void notifyDataChanged() {
    notifyListeners();
  }

  /// ショップのアイテムを更新してUIに通知する（楽観的更新のロールバック用）
  void updateShopAt(int shopIndex, Shop updatedShop) {
    _cacheManager.shops[shopIndex] = updatedShop;
    notifyListeners();
  }

  /// ゲストモードのローカルデータをFirestoreへマイグレーション。
  /// ログイン成功後、ゲストモード終了前に呼ばれる。
  ///
  /// 【Issue #154 の方針】
  /// - 全件の保存成功を確認できた場合のみローカルのゲストデータをクリアする。
  /// - 一部失敗時はローカルデータと移行進捗を残し、次回ログインで再試行する。
  /// - 移行済みID（元ゲストID→クラウドID）の記録で再試行時の重複作成を防ぐ。
  /// - 二重実行をガードする。
  ///
  /// 戻り値の [MigrationResult] で成功/一部失敗を呼び出し側（UI）に伝え、
  /// 失敗時にユーザーへ通知できるようにする。
  Future<MigrationResult> migrateGuestDataToCloud() {
    return _guardedMigrate(() async {
      // ゲストデータは SharedPreferences を正とする。
      // ログイン処理中はキャッシュがリセットされる競合があり得るため、
      // キャッシュではなく永続ストレージから移行対象を読み取る（Issue #154）。
      final (localShops, localItems) =
          await _cacheManager.readGuestDataFromStorage();
      return _migrateData(localShops, localItems);
    });
  }

  /// ログイン後、移行し残したゲストデータがあれば再移行する。
  ///
  /// ゲスト→ログイン移行が一部失敗したとき、ローカルに残ったデータを
  /// 次回ログイン（アプリ起動）時に自動で救済するための入口（Issue #154）。
  /// 残データが無ければ即座に空の結果を返すため、毎回のログインで呼んでも安全。
  Future<MigrationResult> retryPendingGuestMigration() =>
      migrateGuestDataToCloud();

  /// 移行処理を二重実行ガードで包む共通ラッパー。
  Future<MigrationResult> _guardedMigrate(
      Future<MigrationResult> Function() body) async {
    if (_isMigrating) {
      DebugService().logWarning('マイグレーションが既に実行中のためスキップ');
      return MigrationResult.empty;
    }
    _isMigrating = true;
    try {
      return await body();
    } finally {
      _isMigrating = false;
    }
  }

  /// 渡されたショップ/アイテムを Firestore へ移行する中核処理。
  /// 全件成功時のみゲストデータと移行進捗をクリアする。
  Future<MigrationResult> _migrateData(
      List<Shop> localShops, List<ListItem> localItems) async {
    if (localShops.isEmpty && localItems.isEmpty) {
      return MigrationResult.empty;
    }

    DebugService().logInfo(
        'マイグレーション開始: ショップ${localShops.length}件、アイテム${localItems.length}件');

    // 2. これまでの移行進捗を読み込み（前回途中失敗分の再試行・重複防止）
    final (shopIdMap, migratedItemIds) =
        await SettingsPersistence.loadMigrationProgress();

    // 3. ローカルモードをオフにしてFirestoreへの書き込みを有効化
    _cacheManager.setLocalMode(false);
    _state.shouldUseAnonymousSession = false;

    var migratedShops = 0;
    var migratedItems = 0;

    // 4. ショップを保存する（未移行のもののみ）。
    // 新ID採番はクラウド既存データとの競合を回避するため。
    for (final shop in localShops) {
      if (shopIdMap.containsKey(shop.id)) {
        continue; // 既に移行済み → 重複作成しない
      }
      final cloudShopId = shop.id == '0'
          ? '0' // デフォルトショップはID '0' のまま
          : 'migrated_${shop.id}_${DateTime.now().millisecondsSinceEpoch}';
      try {
        final cloudShop = shop.copyWith(
          id: cloudShopId,
          createdAt: shop.createdAt ?? DateTime.now(),
        );
        await _dataService.saveShop(cloudShop, isAnonymous: false);
        shopIdMap[shop.id] = cloudShopId;
        migratedShops++;
        // 成功のたびに進捗を永続化（途中で落ちても記録を残す）
        await SettingsPersistence.saveMigrationProgress(
            shopIdMap, migratedItemIds);
      } catch (e) {
        DebugService().logError('ショップ移行失敗: id=${shop.id} - $e');
        // 失敗は末尾で「進捗に残っていないもの」として集計する。
      }
    }

    // 5. アイテムを保存する。
    // 「属するショップがローカルに存在しない」orphan アイテム（ショップ削除後に
    // 残ったアイテム等）も取りこぼさないよう、全アイテムを対象に走査する。
    final localShopIds = localShops.map((s) => s.id).toSet();
    for (final item in localItems) {
      if (migratedItemIds.contains(item.id)) {
        continue; // 既に移行済み → 重複作成しない
      }
      // 属するショップがローカルに在るのに今回移行できていない場合は、
      // アイテムも保存できないので後回し（末尾で失敗集計→次回再試行）。
      if (localShopIds.contains(item.shopId) &&
          !shopIdMap.containsKey(item.shopId)) {
        continue;
      }
      // 移行済みショップはクラウドIDへ。orphan は元のshopIdのまま保存し、
      // ローカル状態を忠実に保持する（クラウドでも孤立アイテムとして残るが消えない）。
      final cloudShopId = shopIdMap[item.shopId] ?? item.shopId;
      try {
        final cloudItem = item.copyWith(
          shopId: cloudShopId,
          createdAt: item.createdAt ?? DateTime.now(),
        );
        await _dataService.saveItem(cloudItem, isAnonymous: false);
        migratedItemIds.add(item.id);
        migratedItems++;
        await SettingsPersistence.saveMigrationProgress(
            shopIdMap, migratedItemIds);
      } catch (e) {
        DebugService().logError('アイテム移行失敗: id=${item.id} - $e');
      }
    }

    // 6. 失敗件数は「移行進捗に残っていないもの」として集計する。
    // こうすることで、保存できていないデータが1件でもあれば必ず失敗扱いになり、
    // ローカルデータを誤って消すことがない（最優先原則: データを消さない）。
    final failedShops =
        localShops.where((s) => !shopIdMap.containsKey(s.id)).length;
    final failedItems =
        localItems.where((i) => !migratedItemIds.contains(i.id)).length;

    final result = MigrationResult(
      migratedShops: migratedShops,
      migratedItems: migratedItems,
      failedShops: failedShops,
      failedItems: failedItems,
    );

    if (result.isComplete) {
      // 全件成功したときのみローカルのゲストデータと進捗を破棄する
      await SettingsPersistence.clearGuestData();
      await SettingsPersistence.clearMigrationProgress();
      DebugService().logInfo('ゲストデータのFirestoreマイグレーション完了: $result');
    } else {
      // 一部失敗：ローカルデータは残し、進捗を保持して次回ログインで再試行する
      DebugService().logWarning('ゲストデータの移行が一部失敗（ローカルデータは保持）: $result');
    }

    return result;
  }

  void clearData() {
    _syncManager.cancelRealtimeSync();

    _cacheManager.clearData();
    _itemRepository.pendingUpdates.clear();

    _state.isSynced = false;
    final isLoggedIn = _authProvider?.isLoggedIn ?? false;
    final isGuest = _authProvider?.isGuestMode ?? false;
    _cacheManager.setLocalMode(!isLoggedIn || isGuest);

    notifyListeners();
  }

  Future<void> clearAnonymousSession() async {
    try {
      await _dataService.clearAnonymousSession();
    } catch (e) {
      DebugService().logError('匿名セッションクリアエラー: $e');
    }
  }

  void clearDisplayTotalCache() {
    notifyListeners();
  }

  @override
  void dispose() {
    if (_authListener != null) {
      _authProvider?.removeListener(_authListener!);
      _authListener = null;
    }
    _syncManager.cancelRealtimeSync();
    super.dispose();
  }

  // --- 合計・予算計算（SharedTabManagerに委譲） ---

  int getDisplayTotal(Shop shop) {
    return _sharedTabManager.getDisplayTotal(shop);
  }

  int getSharedTabTotal(String sharedTabGroupId) {
    return _sharedTabManager.getSharedTabTotal(sharedTabGroupId);
  }

  int? getSharedTabBudget(String sharedTabGroupId) {
    return _sharedTabManager.getSharedTabBudget(sharedTabGroupId);
  }

  // --- 共有タブ管理（SharedTabManagerに委譲） ---

  Future<void> updateSharedTab(String shopId, List<String> selectedTabIds,
      {String? name, String? sharedTabGroupIcon}) async {
    await _sharedTabManager.updateSharedTab(shopId, selectedTabIds,
        name: name, sharedTabGroupIcon: sharedTabGroupIcon);
  }

  Future<void> removeFromSharedTab(String shopId,
      {String? originalSharedTabGroupId, String? name}) async {
    await _sharedTabManager.removeFromSharedTab(shopId,
        originalSharedTabGroupId: originalSharedTabGroupId, name: name);
  }

  Future<void> syncSharedTabBudget(
      String sharedTabGroupId, int? newBudget) async {
    await _sharedTabManager.syncSharedTabBudget(sharedTabGroupId, newBudget);
  }

  @override
  void notifyListeners() {
    if (_state.isBatchUpdating) return;
    super.notifyListeners();
  }
}
