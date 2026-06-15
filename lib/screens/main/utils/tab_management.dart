import 'package:flutter/material.dart';

import 'package:maikago/models/shop.dart';
import 'package:maikago/services/settings_persistence.dart';
import 'package:maikago/services/debug_service.dart';

/// メイン画面のタブ管理ロジック
class TabManagement {
  /// ショップ数が変わった場合にTabControllerを再作成する
  ///
  /// 再作成が必要な場合は新しいController・タブインデックス・タブIDを返す。
  /// 不要な場合はnullを返す。
  static ({TabController controller, int tabIndex, String? tabId})?
      recreateTabControllerIfNeeded({
    required TabController currentController,
    required List<Shop> sortedShops,
    required String? selectedTabId,
    required int selectedTabIndex,
    required TickerProvider vsync,
    required VoidCallback onTabChanged,
  }) {
    if (sortedShops.isEmpty || currentController.length == sortedShops.length) {
      return null;
    }

    final newLength = sortedShops.length;
    int initialIndex = 0;
    if (newLength > 0) {
      if (selectedTabId != null) {
        final restoredIndex =
            sortedShops.indexWhere((shop) => shop.id == selectedTabId);
        if (restoredIndex != -1) {
          initialIndex = restoredIndex;
        } else {
          initialIndex = selectedTabIndex.clamp(0, newLength - 1);
        }
      } else {
        initialIndex = selectedTabIndex.clamp(0, newLength - 1);
      }
    }

    currentController.removeListener(onTabChanged);
    currentController.dispose();

    final newController = TabController(
      length: sortedShops.length,
      vsync: vsync,
      initialIndex: initialIndex,
    );
    newController.addListener(onTabChanged);

    return (
      controller: newController,
      tabIndex: initialIndex,
      tabId: sortedShops.isNotEmpty ? sortedShops[initialIndex].id : null,
    );
  }

  /// タブ変更イベントの処理
  ///
  /// タブが変更された場合は新しいインデックスとタブIDを返す。
  /// 変更不要（アニメーション中等）の場合はnullを返す。
  static ({int tabIndex, String? tabId})? handleTabChanged({
    required TabController tabController,
    required List<Shop> sortedShops,
  }) {
    if (tabController.indexIsChanging) return null;
    if (tabController.length <= 0) return null;

    final newIndex = tabController.index;
    final safeIndex = newIndex.clamp(0, sortedShops.length - 1);
    final newTabId = sortedShops.isNotEmpty ? sortedShops[safeIndex].id : null;

    SettingsPersistence.saveSelectedTabIndex(newIndex);
    if (newTabId != null) {
      SettingsPersistence.saveSelectedTabId(newTabId);
    }

    return (tabIndex: newIndex, tabId: newTabId);
  }

  /// 保存されたタブインデックスの復元
  static Future<({int tabIndex, String? tabId})?> loadSavedTabIndex() async {
    try {
      final savedIndex = await SettingsPersistence.loadSelectedTabIndex();
      final savedId = await SettingsPersistence.loadSelectedTabId();
      return (
        tabIndex: savedIndex,
        tabId: (savedId == null || savedId.isEmpty) ? null : savedId,
      );
    } catch (e) {
      DebugService().logError('タブインデックス読み込みエラー: $e');
      return null;
    }
  }

  /// タブタップ処理
  ///
  /// タップが有効な場合は新しいインデックスとタブIDを返す。
  /// 無効な場合はnullを返す。
  static ({int tabIndex, String? tabId})? handleTabTap({
    required int index,
    required List<Shop> sortedShops,
    required TabController tabController,
  }) {
    if (sortedShops.isEmpty || index < 0 || index >= sortedShops.length) {
      return null;
    }
    if (tabController.length <= 0 || index >= tabController.length) {
      return null;
    }

    tabController.index = index;

    SettingsPersistence.saveSelectedTabIndex(index);
    final tabId = sortedShops[index].id;
    if (tabId.isNotEmpty) {
      SettingsPersistence.saveSelectedTabId(tabId);
    }

    return (tabIndex: index, tabId: sortedShops[index].id);
  }
}
