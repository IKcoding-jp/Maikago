// データの保持、キャッシュTTL管理、ローカルモード管理、データロード
import 'dart:async';
import 'dart:convert';
import 'package:maikago/services/data_service.dart';
import 'package:maikago/models/list.dart';
import 'package:maikago/models/shop.dart';
import 'package:maikago/providers/data_provider_state.dart';
import 'package:maikago/services/debug_service.dart';
import 'package:maikago/services/settings_persistence.dart';

/// データのインメモリキャッシュとロードを管理するクラス。
/// - items/shopsの保持
/// - キャッシュTTL管理（5分）
/// - データロード（Firebase/ローカル）
/// - アイテム⇔ショップの関連付け
/// - 重複除去
class DataCacheManager {
  DataCacheManager({
    required DataService dataService,
    required DataProviderState state,
  })  : _dataService = dataService,
        _state = state;

  final DataService _dataService;
  final DataProviderState _state;

  List<ListItem> _items = [];
  List<Shop> _shops = [];
  bool _isDataLoaded = false;
  DateTime? _lastSyncTime;
  bool _isLocalMode = false;

  // --- Getter ---
  List<ListItem> get items => _items;
  List<Shop> get shops => _shops;
  bool get isDataLoaded => _isDataLoaded;
  bool get isLocalMode => _isLocalMode;
  DateTime? get lastSyncTime => _lastSyncTime;

  // --- ローカルモード ---
  void setLocalMode(bool isLocal) {
    _isLocalMode = isLocal;
  }

  // --- データロード ---

  /// 初回/認証状態変更時のデータ読み込み（キャッシュ/TTLあり）
  /// [forceReload] が true の場合はキャッシュを無視して再読み込み
  Future<void> loadData({bool forceReload = false}) async {
    // 既にデータが読み込まれている場合はスキップ（キャッシュ最適化）
    if (!forceReload && _isDataLoaded && _items.isNotEmpty) {
      if (_lastSyncTime != null &&
          DateTime.now().difference(_lastSyncTime!).inMinutes < 5) {
        return;
      }
    }

    // 既存データをクリアしてから読み込み
    _items.clear();
    _shops.clear();

    if (_isLocalMode) {
      // ローカルモード: SharedPreferencesから復元
      await _loadFromLocalStorage();
    } else {
      // クラウドモード: Firebaseから読み込み
      await Future.wait([
        _loadItems(),
        _loadShops(),
      ]).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException(
              'データ読み込みがタイムアウトしました', const Duration(seconds: 30));
        },
      );
    }

    _isDataLoaded = true;
    _lastSyncTime = DateTime.now();
    DebugService()
        .logInfo('データ読み込み完了: アイテム${_items.length}件、ショップ${_shops.length}件');
  }

  Future<void> _loadItems() async {
    try {
      _items = await _dataService.getItemsOnce(
        isAnonymous: _state.shouldUseAnonymousSession,
      );
    } catch (e) {
      DebugService().logError('リスト読み込みエラー: $e');
      rethrow;
    }
  }

  Future<void> _loadShops() async {
    try {
      _shops = await _dataService.getShopsOnce(
        isAnonymous: _state.shouldUseAnonymousSession,
      );
    } catch (e) {
      DebugService().logError('ショップ読み込みエラー: $e');
      rethrow;
    }
  }

  // --- ローカルストレージ（ゲストモード用） ---

  /// SharedPreferencesからゲストデータを復元
  Future<void> _loadFromLocalStorage() async {
    try {
      final itemsJson = await SettingsPersistence.loadGuestItems();
      if (itemsJson != null) {
        final List<dynamic> itemsList = json.decode(itemsJson);
        _items = itemsList
            .map((e) => ListItem.fromMap(Map<String, dynamic>.from(e)))
            .toList();
      }

      final shopsJson = await SettingsPersistence.loadGuestShops();
      if (shopsJson != null) {
        final List<dynamic> shopsList = json.decode(shopsJson);
        _shops = shopsList
            .map((e) => Shop.fromMap(Map<String, dynamic>.from(e)))
            .toList();
      }

      DebugService().logInfo(
          'ローカルストレージから復元: アイテム${_items.length}件、ショップ${_shops.length}件');
    } catch (e) {
      DebugService().logError('ローカルストレージ読み込みエラー: $e');
    }
  }

  /// 現在のキャッシュをSharedPreferencesに永続化（ローカルモード時のみ）
  void _persistToLocalStorage() {
    if (!_isLocalMode) return;

    try {
      final itemsJson = json.encode(_items.map((e) => e.toMap()).toList());
      unawaited(SettingsPersistence.saveGuestItems(itemsJson));

      final shopsJson = json.encode(_shops.map((e) => e.toMap()).toList());
      unawaited(SettingsPersistence.saveGuestShops(shopsJson));
    } catch (e) {
      DebugService().logError('ローカルストレージ保存エラー: $e');
    }
  }

  // --- キャッシュ操作（Item） ---

  void addItemToCache(ListItem item) {
    _items.insert(0, item);
    _persistToLocalStorage();
  }

  void updateItemInCache(ListItem item) {
    final index = _items.indexWhere((i) => i.id == item.id);
    if (index != -1) {
      _items[index] = item;
      _persistToLocalStorage();
    }
  }

  void removeItemFromCache(String itemId) {
    _items.removeWhere((item) => item.id == itemId);
    _persistToLocalStorage();
  }

  /// リアルタイム同期用：アイテムリストを一括置換
  void updateItems(List<ListItem> items) {
    _items = items;
  }

  // --- キャッシュ操作（Shop） ---

  void addShopToCache(Shop shop) {
    _shops.add(shop);
    _persistToLocalStorage();
  }

  void updateShopInCache(Shop shop) {
    final index = _shops.indexWhere((s) => s.id == shop.id);
    if (index != -1) {
      _shops[index] = shop;
      _persistToLocalStorage();
    }
  }

  void removeShopFromCache(String shopId) {
    _shops.removeWhere((shop) => shop.id == shopId);
    _persistToLocalStorage();
  }

  /// リアルタイム同期用：ショップリストを一括置換
  void updateShops(List<Shop> shops) {
    _shops = shops;
  }

  // --- 関連付け・重複除去 ---

  /// アイテムをショップに関連付ける（重複除去とIDインデックス化）
  /// [skipIfBatchUpdating] が true で呼び出し元がバッチ更新中の場合はスキップ
  void associateItemsWithShops({bool skipIfBatchUpdating = false}) {
    // ショップIDでインデックスを作成（高速化のため）
    final shopMap = <String, int>{};
    for (int i = 0; i < _shops.length; i++) {
      shopMap[_shops[i].id] = i;
    }

    // ショップごとのアイテムリストを構築
    final shopItems = <String, List<ListItem>>{};
    for (final shop in _shops) {
      shopItems[shop.id] = [];
    }

    // アイテムを対応するショップに振り分け（重複チェック付き）
    final processedItemIds = <String>{};
    final uniqueItems = <ListItem>[];

    for (var item in _items) {
      if (!processedItemIds.contains(item.id)) {
        processedItemIds.add(item.id);
        uniqueItems.add(item);
        shopItems[item.shopId]?.add(item);
      }
    }

    // ショップをitems付きで再構築
    for (int i = 0; i < _shops.length; i++) {
      _shops[i] = _shops[i].copyWith(items: shopItems[_shops[i].id] ?? []);
    }

    _items = uniqueItems;
  }

  /// 重複ショップを除去（IDベース）
  void removeDuplicateShops() {
    final Map<String, Shop> uniqueShopsMap = {};
    final List<Shop> uniqueShops = [];

    for (final shop in _shops) {
      if (!uniqueShopsMap.containsKey(shop.id)) {
        uniqueShopsMap[shop.id] = shop;
        uniqueShops.add(shop);
      }
    }

    _shops = uniqueShops;
  }

  /// 重複アイテムを除去
  void removeDuplicateItems() {
    final Map<String, ListItem> uniqueItemsMap = {};
    final List<ListItem> uniqueItems = [];

    for (final item in _items) {
      if (!uniqueItemsMap.containsKey(item.id)) {
        uniqueItemsMap[item.id] = item;
        uniqueItems.add(item);
      }
    }

    _items = uniqueItems;
  }

  // --- データクリア ---

  /// データとフラグをすべてクリア
  void clearData() {
    _items.clear();
    _shops.clear();
    _isDataLoaded = false;
    _lastSyncTime = null;
  }

  /// フラグのみリセット（ログイン時のデータ切り替え用）
  void resetFlags() {
    _isDataLoaded = false;
    _lastSyncTime = null;
  }

  /// TTLのみリセット（認証状態変更時に確実に再読み込みさせる）
  void clearLastSyncTime() {
    _lastSyncTime = null;
    _isDataLoaded = false;
  }
}
