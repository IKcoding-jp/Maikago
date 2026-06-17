// 同期タブのCRUD、合計・予算計算
import 'package:maikago/services/data_service.dart';
import 'package:maikago/models/shop.dart';
import 'package:maikago/providers/data_provider_state.dart';
import 'package:maikago/providers/managers/data_cache_manager.dart';
import 'package:maikago/providers/repositories/shop_repository.dart';
import 'package:maikago/services/debug_service.dart';
import 'package:maikago/utils/calculation_utils.dart';

/// 同期タブの管理を担うクラス。
/// - 同期タブの作成・更新・削除
/// - 同期タブ間の参照管理
/// - 合計・予算の計算
/// - Firestore保存
class SyncTabManager {
  SyncTabManager({
    required DataService dataService,
    required DataCacheManager cacheManager,
    required ShopRepository shopRepository,
    required DataProviderState state,
  })  : _dataService = dataService,
        _cacheManager = cacheManager,
        _shopRepository = shopRepository,
        _state = state;

  final DataService _dataService;
  final DataCacheManager _cacheManager;
  final ShopRepository _shopRepository;
  final DataProviderState _state;

  // --- 合計・予算計算 ---

  int getDisplayTotal(Shop shop) => calcShopTotal(shop);

  int getSharedTabTotal(String sharedTabGroupId) {
    final sharedShops = _cacheManager.shops
        .where((shop) => shop.sharedTabGroupId == sharedTabGroupId)
        .toList();
    return sharedShops.fold<int>(
        0, (total, shop) => total + getDisplayTotal(shop));
  }

  int? getSharedTabBudget(String sharedTabGroupId) {
    final sharedShops = _cacheManager.shops
        .where((shop) => shop.sharedTabGroupId == sharedTabGroupId)
        .toList();

    for (final shop in sharedShops) {
      if (shop.budget != null) {
        return shop.budget!;
      }
    }

    return null;
  }

  // --- 同期タブ管理 ---

  Future<void> updateSharedTab(String shopId, List<String> selectedTabIds,
      {String? name, String? sharedTabGroupIcon}) async {
    String? sharedTabGroupId;
    final currentShop =
        _cacheManager.shops.firstWhere((shop) => shop.id == shopId);

    if (currentShop.sharedTabGroupId != null) {
      sharedTabGroupId = currentShop.sharedTabGroupId;
    } else {
      sharedTabGroupId = 'shared_${DateTime.now().millisecondsSinceEpoch}';
    }

    final previousSharedTabs = currentShop.sharedTabs;
    final removedTabIds =
        previousSharedTabs.where((id) => !selectedTabIds.contains(id)).toList();

    // Issue #159: 失敗時に巻き戻すため、関係ショップの更新前状態を退避する
    final involvedIds = <String>{
      shopId,
      ...selectedTabIds,
      ...previousSharedTabs
    };
    final originalById = _snapshot(involvedIds);

    final updatedShop = currentShop.copyWith(
      name: name ?? currentShop.name,
      sharedTabs: selectedTabIds,
      sharedTabGroupId: selectedTabIds.isEmpty ? null : sharedTabGroupId,
      clearSharedTabGroupId: selectedTabIds.isEmpty,
      sharedTabGroupIcon: selectedTabIds.isEmpty ? null : sharedTabGroupIcon,
      clearSharedTabGroupIcon: selectedTabIds.isEmpty,
    );

    final shopIndex =
        _cacheManager.shops.indexWhere((shop) => shop.id == shopId);
    if (shopIndex != -1) {
      _cacheManager.shops[shopIndex] = updatedShop;
      _shopRepository.pendingUpdates[shopId] = DateTime.now();
    }

    // グループ全体のID（解除タブの参照除去に使用）
    final allInvolvedIds = {shopId, ...selectedTabIds, ...removedTabIds};

    // 解除されたタブからグループ全メンバーへの参照を除去
    for (final removedTabId in removedTabIds) {
      final removedTabIndex =
          _cacheManager.shops.indexWhere((shop) => shop.id == removedTabId);
      if (removedTabIndex != -1) {
        final removedTab = _cacheManager.shops[removedTabIndex];
        final updatedSharedTabs = removedTab.sharedTabs
            .where((id) => !allInvolvedIds.contains(id))
            .toList();
        final updatedRemovedTab = removedTab.copyWith(
          sharedTabs: updatedSharedTabs,
          clearSharedTabGroupId: updatedSharedTabs.isEmpty,
        );
        _cacheManager.shops[removedTabIndex] = updatedRemovedTab;
        _shopRepository.pendingUpdates[removedTabId] = DateTime.now();
      }
    }

    // 同期タブの全メンバーID（自身 + 選択タブ）
    final allGroupMemberIds = {shopId, ...selectedTabIds};

    // 選択されたタブのsharedTabsを正確なグループメンバーに置換
    for (final tabId in selectedTabIds) {
      final tabIndex =
          _cacheManager.shops.indexWhere((shop) => shop.id == tabId);
      if (tabIndex != -1) {
        // addAllではなく、正確なメンバーリストに置換（解除タブの残留を防止）
        final updatedSharedTabs =
            allGroupMemberIds.where((id) => id != tabId).toList();
        final updatedTabShop = _cacheManager.shops[tabIndex].copyWith(
          sharedTabGroupId: sharedTabGroupId,
          sharedTabs: updatedSharedTabs,
          sharedTabGroupIcon: sharedTabGroupIcon,
        );
        _cacheManager.shops[tabIndex] = updatedTabShop;
        _shopRepository.pendingUpdates[tabId] = DateTime.now();
      }
    }

    _state.notifyListeners();

    if (!_cacheManager.isLocalMode) {
      // 更新対象（自身 + 解除タブ + 選択タブ）を集めて1回のバッチで保存する
      final idsToPersist = <String>{
        shopId,
        ...removedTabIds,
        ...selectedTabIds
      };
      final shopsToPersist = _collectShops(idsToPersist);

      try {
        await _dataService.updateShopsBatch(
          shopsToPersist,
          isAnonymous: _state.shouldUseAnonymousSession,
        );

        _state.isSynced = true;
        DebugService().logInfo('同期タブ更新完了: ショップID=$shopId');
      } catch (e) {
        _state.isSynced = false;
        DebugService().logError('同期タブ更新エラー: $e');
        // Issue #159: 途中失敗時は全ショップを更新前へ巻き戻す
        _rollback(originalById, involvedIds);
        _state.notifyListeners();
        rethrow;
      }
    }
  }

  Future<void> removeFromSharedTab(String shopId,
      {String? originalSharedTabGroupId, String? name}) async {
    final shopIndex =
        _cacheManager.shops.indexWhere((shop) => shop.id == shopId);
    if (shopIndex == -1) return;

    final currentShop = _cacheManager.shops[shopIndex];
    String? sharedTabGroupId =
        originalSharedTabGroupId ?? currentShop.sharedTabGroupId;
    if (sharedTabGroupId == null) {
      for (final shop in _cacheManager.shops) {
        if (shop.sharedTabs.contains(shopId)) {
          sharedTabGroupId = shop.sharedTabGroupId;
          break;
        }
      }
    }

    // Issue #159: 失敗時に巻き戻すため、関係ショップの更新前状態を退避する
    final involvedIds = <String>{shopId};
    for (final shop in _cacheManager.shops) {
      if (shop.id != shopId && shop.sharedTabs.contains(shopId)) {
        involvedIds.add(shop.id);
      }
    }
    final originalById = _snapshot(involvedIds);

    final updatedShop = currentShop.copyWith(
      name: name ?? currentShop.name,
      sharedTabs: [],
      clearSharedTabGroupId: true,
    );
    _cacheManager.shops[shopIndex] = updatedShop;
    _shopRepository.pendingUpdates[shopId] = DateTime.now();

    final affectedShopIds = <String>[];

    for (int i = 0; i < _cacheManager.shops.length; i++) {
      final otherShop = _cacheManager.shops[i];
      if (otherShop.id == shopId) continue;
      if (!otherShop.sharedTabs.contains(shopId)) continue;

      final updatedSharedTabs =
          otherShop.sharedTabs.where((id) => id != shopId).toList();
      final updatedOtherShop = otherShop.copyWith(
        sharedTabs: updatedSharedTabs,
        clearSharedTabGroupId: updatedSharedTabs.isEmpty,
      );
      _cacheManager.shops[i] = updatedOtherShop;
      _shopRepository.pendingUpdates[updatedOtherShop.id] = DateTime.now();
      affectedShopIds.add(updatedOtherShop.id);
    }

    _state.notifyListeners();

    if (!_cacheManager.isLocalMode) {
      // 離脱ショップ + 参照を外した関係ショップを1回のバッチで保存する
      final idsToPersist = <String>{shopId, ...affectedShopIds};
      final shopsToPersist = _collectShops(idsToPersist);

      try {
        await _dataService.updateShopsBatch(
          shopsToPersist,
          isAnonymous: _state.shouldUseAnonymousSession,
        );

        _state.isSynced = true;
        DebugService().logInfo('同期タブから離脱完了: ショップID=$shopId');
      } catch (e) {
        _state.isSynced = false;
        DebugService().logError('同期タブ削除エラー: $e');
        // Issue #159: 途中失敗時は全ショップを更新前へ巻き戻す
        _rollback(originalById, involvedIds);
        _state.notifyListeners();
        rethrow;
      }
    }
  }

  Future<void> syncSharedTabBudget(
      String sharedTabGroupId, int? newBudget) async {
    final sharedShops = _cacheManager.shops
        .where((shop) => shop.sharedTabGroupId == sharedTabGroupId)
        .toList();

    // Issue #159: 失敗時に巻き戻すため、関係ショップの更新前状態を退避する
    final involvedIds = sharedShops.map((shop) => shop.id).toSet();
    final originalById = _snapshot(involvedIds);

    for (final shop in sharedShops) {
      final updatedShop = (newBudget == null || newBudget == 0)
          ? shop.copyWith(clearBudget: true)
          : shop.copyWith(budget: newBudget);
      final shopIndex = _cacheManager.shops.indexWhere((s) => s.id == shop.id);
      if (shopIndex != -1) {
        _cacheManager.shops[shopIndex] = updatedShop;
      }
    }

    _state.notifyListeners();

    if (!_cacheManager.isLocalMode) {
      final shopsToPersist = _collectShops(involvedIds);

      try {
        await _dataService.updateShopsBatch(
          shopsToPersist,
          isAnonymous: _state.shouldUseAnonymousSession,
        );

        _state.isSynced = true;
      } catch (e) {
        _state.isSynced = false;
        DebugService().logError('同期タブ予算同期エラー: $e');
        // Issue #159: 途中失敗時は全ショップを更新前へ巻き戻す
        _rollback(originalById, involvedIds);
        _state.notifyListeners();
        rethrow;
      }
    }
  }

  // --- Issue #159: 原子的更新の補助メソッド ---

  /// 指定IDの現在のショップ状態（更新前）を退避する。
  Map<String, Shop> _snapshot(Iterable<String> ids) {
    final result = <String, Shop>{};
    for (final id in ids) {
      final index = _cacheManager.shops.indexWhere((shop) => shop.id == id);
      if (index != -1) {
        result[id] = _cacheManager.shops[index];
      }
    }
    return result;
  }

  /// 指定IDの現在のショップをキャッシュから集めてリスト化する（バッチ保存用）。
  List<Shop> _collectShops(Iterable<String> ids) {
    final result = <Shop>[];
    for (final id in ids) {
      final index = _cacheManager.shops.indexWhere((shop) => shop.id == id);
      if (index != -1) {
        result.add(_cacheManager.shops[index]);
      }
    }
    return result;
  }

  /// 退避しておいた状態へキャッシュを巻き戻し、保留中フラグも除去する。
  void _rollback(Map<String, Shop> originalById, Iterable<String> involvedIds) {
    for (final id in involvedIds) {
      final original = originalById[id];
      final index = _cacheManager.shops.indexWhere((shop) => shop.id == id);
      if (index != -1 && original != null) {
        _cacheManager.shops[index] = original;
      }
      _shopRepository.pendingUpdates.remove(id);
    }
  }
}
