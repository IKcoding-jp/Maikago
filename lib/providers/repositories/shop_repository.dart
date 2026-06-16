// ショップのCRUD操作、楽観的更新、デフォルトショップ管理
import 'package:maikago/services/data_service.dart';
import 'package:maikago/models/shop.dart';
import 'package:maikago/models/sort_mode.dart';
import 'package:maikago/services/settings_persistence.dart';
import 'package:maikago/providers/data_provider_state.dart';
import 'package:maikago/providers/managers/data_cache_manager.dart';
import 'package:maikago/services/debug_service.dart';
import 'package:maikago/utils/exceptions.dart';

/// ショップのCRUD操作を管理するリポジトリ。
/// - 楽観的更新（即座にキャッシュを更新し、バックグラウンドでFirebase保存）
/// - バウンス抑止（保留中のショップIDを追跡）
/// - デフォルトショップの自動作成
/// - エラー時のロールバック
class ShopRepository {
  ShopRepository({
    required DataService dataService,
    required DataCacheManager cacheManager,
    required DataProviderState state,
  })  : _dataService = dataService,
        _cacheManager = cacheManager,
        _state = state;

  final DataService _dataService;
  final DataCacheManager _cacheManager;
  final DataProviderState _state;

  /// 直近で更新を行ったショップのIDとタイムスタンプ（楽観更新のバウンス抑止）
  final Map<String, DateTime> pendingUpdates = {};

  // --- デフォルトショップ管理 ---

  /// デフォルトショップ（id:'0'）を確保
  /// ローカルモード: id:'0'が存在しなければ作成（削除済みフラグがある場合は除く）
  /// クラウドモード: ショップが0個の場合のみ作成しFirestoreにも保存
  Future<void> ensureDefaultShop() async {
    // ローカルモードではデフォルトショップ削除済みフラグを確認
    if (_cacheManager.isLocalMode) {
      final isDefaultShopDeleted =
          await SettingsPersistence.loadDefaultShopDeleted();
      if (isDefaultShopDeleted) {
        return;
      }
    }

    // デフォルトショップが必要かどうか判定
    // ローカルモード: id:'0'のショップが存在しなければ作成
    // クラウドモード: ショップが1つもなければ作成（新規ユーザー対応）
    final needsDefaultShop = _cacheManager.isLocalMode
        ? !_cacheManager.shops.any((shop) => shop.id == '0')
        : _cacheManager.shops.isEmpty;

    if (needsDefaultShop) {
      final defaultShop = Shop(
        id: '0',
        name: 'デフォルト',
        items: [],
        createdAt: DateTime.now(),
      );
      _cacheManager.addShopToCache(defaultShop);

      // クラウドモードの場合はFirestoreにも保存
      if (!_cacheManager.isLocalMode) {
        try {
          await _dataService.saveShop(
            defaultShop,
            isAnonymous: _state.shouldUseAnonymousSession,
          );
        } catch (e) {
          DebugService().logError('デフォルトショップのFirebase保存エラー: $e');
        }
      }

      // 即座に通知してUIを更新
      _state.notifyListeners();
    }
  }

  // --- ショップ追加 ---

  Future<void> addShop(Shop shop) async {
    // デフォルトショップ（ID: '0'）の場合は制限チェックをスキップ
    if (shop.id == '0') {
      final Shop newShop = shop.copyWith(createdAt: DateTime.now());
      // デフォルトショップの削除状態をリセット
      await SettingsPersistence.saveDefaultShopDeleted(false);

      _cacheManager.addShopToCache(newShop);
      _state.notifyListeners(); // 即座にUIを更新

      // ローカルモードでない場合のみFirebaseに保存
      if (!_cacheManager.isLocalMode) {
        try {
          await _dataService.saveShop(
            newShop,
            isAnonymous: _state.shouldUseAnonymousSession,
          );
          _state.isSynced = true;
        } catch (e) {
          _state.isSynced = false;
          DebugService().logError('Firebase保存エラー: $e');

          // エラーが発生した場合は追加を取り消し
          _cacheManager.shops.removeLast();
          _state.notifyListeners();
          rethrow;
        }
      }
      return;
    }

    // 通常のショップの場合は新しいIDを生成
    final newShop = shop.copyWith(
      id: '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}_${_cacheManager.shops.length}',
      createdAt: DateTime.now(),
    );

    _cacheManager.addShopToCache(newShop);
    _state.notifyListeners(); // 即座にUIを更新

    // ローカルモードでない場合のみFirebaseに保存
    if (!_cacheManager.isLocalMode) {
      try {
        await _dataService.saveShop(
          newShop,
          isAnonymous: _state.shouldUseAnonymousSession,
        );
        _state.isSynced = true;
      } catch (e) {
        _state.isSynced = false;
        DebugService().logError('Firebase保存エラー: $e');

        // エラーが発生した場合は追加を取り消し
        _cacheManager.shops.removeLast();

        // デフォルトショップの場合は削除状態を復元
        if (shop.id == '0') {
          await SettingsPersistence.saveDefaultShopDeleted(true);
        }

        _state.notifyListeners();
        rethrow;
      }
    }
  }

  // --- ショップ更新 ---

  Future<void> updateShop(Shop shop) async {
    // 楽観的更新：UIを即座に更新
    final index = _cacheManager.shops.indexWhere((s) => s.id == shop.id);
    Shop? originalShop;

    if (index != -1) {
      originalShop = _cacheManager.shops[index]; // 元の状態を保存
      _cacheManager.shops[index] = shop;
      // 楽観的更新の保護
      pendingUpdates[shop.id] = DateTime.now();

      // バッチ更新中でない場合のみUIを更新
      if (!_state.isBatchUpdating) {
        _state.notifyListeners(); // 即座にUIを更新
      }
    }

    // ローカルモードでない場合のみFirebaseに保存
    if (!_cacheManager.isLocalMode) {
      try {
        await _dataService.updateShop(
          shop,
          isAnonymous: _state.shouldUseAnonymousSession,
        );
        _state.isSynced = true;
      } catch (e) {
        _state.isSynced = false;
        DebugService().logError('Firebase更新エラー: $e');

        // エラーが発生した場合は元に戻す
        if (index != -1 && originalShop != null) {
          _cacheManager.shops[index] = originalShop; // 元の状態に戻す
          _state.notifyListeners();
        }

        throw convertToAppException(e, contextMessage: 'ショップの更新');
      }
    }
  }

  // --- ショップ削除 ---

  Future<void> deleteShop(String shopId) async {
    // 楽観的更新：UIを即座に更新
    final shopToDelete = _cacheManager.shops.firstWhere(
      (shop) => shop.id == shopId,
      orElse: () => throw Exception('削除対象のショップが見つかりません'),
    );

    // 削除されたタブを他のタブのsharedTabsから削除
    // Issue #159: 影響を受けたショップIDと更新前状態を記録する
    // （IDは後のバッチ更新に、更新前状態は失敗時のロールバックに使う）
    final affectedShopIds = <String>[];
    final originalAffectedShops = <String, Shop>{};
    for (int i = 0; i < _cacheManager.shops.length; i++) {
      final shop = _cacheManager.shops[i];
      if (shop.sharedTabs.contains(shopId)) {
        // 削除されたタブへの参照を削除
        final updatedSharedTabs =
            shop.sharedTabs.where((id) => id != shopId).toList();

        // 共有相手がいなくなった場合は共有マークも削除
        final updatedShop = shop.copyWith(
          sharedTabs: updatedSharedTabs,
          clearSharedTabGroupId: updatedSharedTabs.isEmpty,
          clearSharedTabGroupIcon: updatedSharedTabs.isEmpty,
        );

        originalAffectedShops[shop.id] = shop;
        _cacheManager.shops[i] = updatedShop;
        pendingUpdates[shop.id] = DateTime.now();
        affectedShopIds.add(updatedShop.id);
      }
    }

    _cacheManager.removeShopFromCache(shopId);
    _state.notifyListeners(); // 即座にUIを更新

    // デフォルトショップが削除された場合は状態を記録
    if (shopId == '0') {
      await SettingsPersistence.saveDefaultShopDeleted(true);
    }

    // ローカルモードでない場合のみFirebaseから削除
    if (!_cacheManager.isLocalMode) {
      try {
        await _dataService.deleteShop(
          shopId,
          isAnonymous: _state.shouldUseAnonymousSession,
        );

        // Issue #159: 参照を外した共有相手を WriteBatch でまとめて保存する
        // （順次 await だと途中失敗で一部だけ更新される不整合が残るため）
        final affectedShops = affectedShopIds
            .map(
                (id) => _cacheManager.shops.indexWhere((shop) => shop.id == id))
            .where((index) => index != -1)
            .map((index) => _cacheManager.shops[index])
            .toList();
        if (affectedShops.isNotEmpty) {
          await _dataService.updateShopsBatch(
            affectedShops,
            isAnonymous: _state.shouldUseAnonymousSession,
          );
        }

        _state.isSynced = true;
      } catch (e) {
        _state.isSynced = false;
        DebugService().logError('Firebase削除エラー: $e');

        // エラーが発生した場合は削除を取り消し
        _cacheManager.addShopToCache(shopToDelete);

        // Issue #159: 参照を外した共有相手も更新前の状態へ巻き戻す
        for (final entry in originalAffectedShops.entries) {
          final index =
              _cacheManager.shops.indexWhere((shop) => shop.id == entry.key);
          if (index != -1) {
            _cacheManager.shops[index] = entry.value;
          }
          pendingUpdates.remove(entry.key);
        }
        // 削除対象自身の保留フラグも除去する
        pendingUpdates.remove(shopId);

        // デフォルトショップの削除記録も取り消し
        if (shopId == '0') {
          await SettingsPersistence.saveDefaultShopDeleted(false);
        }

        _state.notifyListeners();
        rethrow;
      }
    }
  }

  // --- ショップ補助メソッド ---

  // ショップ名を更新
  void updateShopName(int index, String newName) {
    if (index >= 0 && index < _cacheManager.shops.length) {
      _cacheManager.shops[index] =
          _cacheManager.shops[index].copyWith(name: newName);
      if (!_cacheManager.isLocalMode) {
        _dataService.saveShop(
          _cacheManager.shops[index],
          isAnonymous: _state.shouldUseAnonymousSession,
        );
      }
      _state.notifyListeners();
    }
  }

  // ショップの予算を更新
  void updateShopBudget(int index, int? budget) {
    if (index >= 0 && index < _cacheManager.shops.length) {
      _cacheManager.shops[index] =
          _cacheManager.shops[index].copyWith(budget: budget);
      if (!_cacheManager.isLocalMode) {
        _dataService.saveShop(
          _cacheManager.shops[index],
          isAnonymous: _state.shouldUseAnonymousSession,
        );
      }
      _state.notifyListeners();
    }
  }

  // すべてのリストを削除
  void clearAllItems(int shopIndex) {
    if (shopIndex >= 0 && shopIndex < _cacheManager.shops.length) {
      _cacheManager.shops[shopIndex] =
          _cacheManager.shops[shopIndex].copyWith(items: []);
      if (!_cacheManager.isLocalMode) {
        _dataService.saveShop(
          _cacheManager.shops[shopIndex],
          isAnonymous: _state.shouldUseAnonymousSession,
        );
      }
      _state.notifyListeners();
    }
  }

  // ソートモードを更新
  void updateSortMode(int shopIndex, SortMode sortMode, bool isIncomplete) {
    if (shopIndex >= 0 && shopIndex < _cacheManager.shops.length) {
      if (isIncomplete) {
        _cacheManager.shops[shopIndex] =
            _cacheManager.shops[shopIndex].copyWith(incSortMode: sortMode);
      } else {
        _cacheManager.shops[shopIndex] =
            _cacheManager.shops[shopIndex].copyWith(comSortMode: sortMode);
      }
      if (!_cacheManager.isLocalMode) {
        _dataService.saveShop(
          _cacheManager.shops[shopIndex],
          isAnonymous: _state.shouldUseAnonymousSession,
        );
      }
      _state.notifyListeners();
    }
  }
}
