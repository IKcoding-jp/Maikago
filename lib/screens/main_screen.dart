import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:maikago/providers/data_provider.dart';
import 'package:maikago/providers/auth_provider.dart';
import 'package:maikago/providers/theme_provider.dart';
import 'package:maikago/services/settings_persistence.dart';
import 'package:maikago/models/list.dart';
import 'package:maikago/models/shop.dart';
import 'package:maikago/models/sort_mode.dart';
import 'package:maikago/utils/tab_sorter.dart';

import 'package:maikago/services/ad/ad_banner.dart';
import 'package:maikago/screens/main/dialogs/item_rename_dialog.dart';
import 'package:maikago/screens/main/widgets/bottom_summary_widget.dart';
import 'package:maikago/screens/main/widgets/main_app_bar.dart';
import 'package:maikago/screens/main/widgets/main_drawer.dart';
import 'package:maikago/screens/main/widgets/item_list_section.dart';
import 'package:maikago/screens/main/utils/ui_calculations.dart';
import 'package:maikago/screens/main/utils/item_operations.dart';
import 'package:maikago/screens/main/utils/startup_helpers.dart';
import 'package:maikago/screens/main/utils/dialog_handlers.dart';
import 'package:maikago/screens/main/utils/tab_management.dart';
import 'package:maikago/services/settings_theme.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  late TabController tabController;
  int selectedTabIndex = 0;
  String? selectedTabId;
  Map<String, Color> customColors = {
    'primary': AppColors.primary,
    'secondary': AppColors.secondary,
    'surface': AppColors.surface,
  };

  // コーチマーク用 GlobalKey
  final GlobalKey coachFabKey = GlobalKey(debugLabel: 'coachFab');
  final GlobalKey coachItemListKey = GlobalKey(debugLabel: 'coachItemList');
  final GlobalKey coachAddTabKey = GlobalKey(debugLabel: 'coachAddTab');
  final GlobalKey coachBudgetKey = GlobalKey(debugLabel: 'coachBudget');
  String nextShopId = '1';
  bool includeTax = false;
  bool _strikethroughEnabled = false;

  String get currentTheme => context.read<ThemeProvider>().selectedTheme;
  String get currentFont => context.read<ThemeProvider>().selectedFont;
  double get currentFontSize => context.read<ThemeProvider>().fontSize;

  Future<void> _checkForVersionUpdate() =>
      StartupHelpers.checkForVersionUpdate(context);

  // --- ダイアログ表示 ---

  void showAddTabDialog() {
    if (!mounted) return;
    DialogHandlers.showAddTabDialog(
      context,
      nextShopId: nextShopId,
      onNextShopIdChanged: (newId) => setState(() => nextShopId = newId),
    );
  }

  void showBudgetDialog(Shop shop) =>
      DialogHandlers.showBudgetDialog(context, shop);

  void showTabEditDialog(int tabIndex, List<Shop> shops) =>
      DialogHandlers.showTabEditDialog(context,
          tabIndex: tabIndex, shops: shops);

  void showItemEditDialog({ListItem? original, required Shop shop}) =>
      DialogHandlers.showItemEditDialog(context,
          original: original, shop: shop);

  void showSortDialog(bool isIncomplete, Shop shop) {
    DialogHandlers.showSortDialog(
      context,
      isIncomplete: isIncomplete,
      shop: shop,
      onSortChanged: () {
        if (mounted) setState(() {});
      },
    );
  }

  void showBulkDeleteDialog(Shop shop, bool isIncomplete) {
    if (!mounted) return;
    DialogHandlers.showBulkDeleteDialog(
      context,
      shop: shop,
      isIncomplete: isIncomplete,
    );
  }

  // --- アイテム操作 ---

  Future<void> _reorderItems(int oldIndex, int newIndex,
      {required bool isIncomplete}) async {
    final result = await ItemOperations.reorderItems(
      context,
      selectedTabId: selectedTabId,
      selectedTabIndex: selectedTabIndex,
      oldIndex: oldIndex,
      newIndex: newIndex,
      isIncomplete: isIncomplete,
    );
    if (result != null) {
      selectedTabIndex = result.tabIndex;
      selectedTabId = result.tabId;
    }
  }

  Future<void> _reorderIncItems(int oldIndex, int newIndex) =>
      _reorderItems(oldIndex, newIndex, isIncomplete: true);

  Future<void> _reorderComItems(int oldIndex, int newIndex) =>
      _reorderItems(oldIndex, newIndex, isIncomplete: false);

  // --- ライフサイクル ---

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 1, vsync: this);
    tabController.addListener(onTabChanged);
    _loadStrikethroughSetting();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      checkAndShowWelcomeDialog();
      _checkForVersionUpdate();
      loadSavedTabIndex();
      final dataProvider = context.read<DataProvider>();
      final authProvider = context.read<AuthProvider>();
      // リスナーを先に登録してから setAuthProvider を呼ぶ（同期通知を取りこぼさないため）
      dataProvider.addListener(_onDataProviderChanged);
      dataProvider.setAuthProvider(authProvider);
      // データが既にロード済みの場合（setAuthProvider が早期リターンするケース等）に
      // TabController の length を即時同期する
      _onDataProviderChanged();
    });
  }

  Future<void> _loadStrikethroughSetting() async {
    final enabled = await SettingsPersistence.loadStrikethrough();
    if (mounted) {
      setState(() {
        _strikethroughEnabled = enabled;
      });
    }
  }

  @override
  void dispose() {
    // DataProviderリスナー解除（mountedの場合のみ）
    try {
      context.read<DataProvider>().removeListener(_onDataProviderChanged);
    } catch (_) {
      // dispose時にcontextが無効な場合は無視
    }
    tabController.removeListener(onTabChanged);
    tabController.dispose();
    super.dispose();
  }

  // --- タブ管理 ---

  /// DataProviderの変更を検知してTabControllerを更新
  void _onDataProviderChanged() {
    if (!mounted) return;
    final dataProvider = context.read<DataProvider>();
    final sortedShops = TabSorter.sortShopsBySharedTabs(dataProvider.shops);
    final result = TabManagement.recreateTabControllerIfNeeded(
      currentController: tabController,
      sortedShops: sortedShops,
      selectedTabId: selectedTabId,
      selectedTabIndex: selectedTabIndex,
      vsync: this,
      onTabChanged: onTabChanged,
    );
    if (result != null) {
      setState(() {
        tabController = result.controller;
        selectedTabIndex = result.tabIndex;
        selectedTabId = result.tabId;
      });
    }
  }

  Future<void> checkAndShowWelcomeDialog() =>
      StartupHelpers.checkAndShowWelcomeDialog(
        context,
        fabKey: coachFabKey,
        itemListKey: coachItemListKey,
        addTabKey: coachAddTabKey,
        budgetKey: coachBudgetKey,
      );

  void onTabChanged() {
    if (!mounted) return;
    final dataProvider = context.read<DataProvider>();
    final sortedShops = TabSorter.sortShopsBySharedTabs(dataProvider.shops);
    final result = TabManagement.handleTabChanged(
      tabController: tabController,
      sortedShops: sortedShops,
    );
    if (result != null) {
      setState(() {
        selectedTabIndex = result.tabIndex;
        selectedTabId = result.tabId;
      });
    }
  }

  Future<void> loadSavedTabIndex() async {
    final result = await TabManagement.loadSavedTabIndex();
    if (result != null && mounted) {
      setState(() {
        selectedTabIndex = result.tabIndex;
        selectedTabId = result.tabId;
      });
    }
  }

  void updateCustomColors(Map<String, Color> colors) {
    setState(() {
      customColors = Map<String, Color>.from(colors);
    });
  }

  void _handleTabTap(int index, List<Shop> sortedShops) {
    if (!mounted) return;
    final result = TabManagement.handleTabTap(
      index: index,
      sortedShops: sortedShops,
      tabController: tabController,
    );
    if (result != null) {
      setState(() {
        selectedTabIndex = result.tabIndex;
        selectedTabId = result.tabId;
      });
    }
  }

  // --- アイテム操作コールバック ---

  Future<void> _handleCheckToggle(ListItem item, bool checked) =>
      ItemOperations.handleCheckToggle(
        context,
        item: item,
        checked: checked,
        selectedTabId: selectedTabId,
        selectedTabIndex: selectedTabIndex,
      );

  /// アイテム削除処理
  Future<void> _handleDelete(ListItem item) =>
      ItemOperations.deleteItem(context, item: item);

  /// アイテム更新処理
  Future<void> _handleUpdate(ListItem updatedItem) =>
      ItemOperations.updateItem(context, updatedItem: updatedItem);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scaffoldBgLuminance =
        theme.scaffoldBackgroundColor.computeLuminance();

    return Consumer<DataProvider>(
      builder: (context, dataProvider, child) {
        final sortedShops = TabSorter.sortShopsBySharedTabs(dataProvider.shops);

        final selectedIndex = sortedShops.isEmpty
            ? 0
            : (tabController.index >= 0 &&
                    tabController.index < sortedShops.length)
                ? tabController.index
                : 0;

        if (dataProvider.isLoading) {
          return Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'データを読み込み中...',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final shop = sortedShops.isEmpty
            ? null
            : sortedShops[selectedIndex.clamp(
                0,
                sortedShops.length - 1,
              )];
        if (shop != null) {
          selectedTabId = shop.id;
        }

        final incItems = shop?.items.where((e) => !e.isChecked).toList() ?? [];
        if (shop == null || shop.incSortMode == SortMode.manual) {
          incItems.sort(MainScreenCalculations.comparatorFor(SortMode.manual));
        } else {
          incItems.sort(MainScreenCalculations.comparatorFor(shop.incSortMode));
        }
        final comItems = shop?.items.where((e) => e.isChecked).toList() ?? [];
        if (shop == null || shop.comSortMode == SortMode.manual) {
          comItems.sort(MainScreenCalculations.comparatorFor(SortMode.manual));
        } else {
          comItems.sort(MainScreenCalculations.comparatorFor(shop.comSortMode));
        }

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          extendBodyBehindAppBar: false,
          appBar: MainAppBar(
            sortedShops: sortedShops,
            selectedIndex: selectedIndex,
            currentTheme: currentTheme,
            customColors: customColors,
            theme: theme,
            scaffoldBgLuminance: scaffoldBgLuminance,
            onTabTap: (index) => _handleTabTap(index, sortedShops),
            onTabLongPress: (originalIndex) {
              showTabEditDialog(originalIndex, dataProvider.shops);
            },
            onAddTab: showAddTabDialog,
            addTabKey: coachAddTabKey,
          ),
          drawer: MainDrawer(
            theme: theme,
            currentTheme: currentTheme,
            currentFont: currentFont,
            currentFontSize: currentFontSize,
            drawerItemColor: currentTheme == 'dark'
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.primary,
            drawerTextColor:
                currentTheme == 'dark' ? theme.colorScheme.onPrimary : null,
            onCustomColorsChanged: updateCustomColors,
            onSettingsReturned: () {
              _loadStrikethroughSetting();
            },
          ),
          body: ItemListSection(
            shop: shop,
            incItems: incItems,
            comItems: comItems,
            strikethroughEnabled: _strikethroughEnabled,
            theme: theme,
            onCheckToggle: _handleCheckToggle,
            onEdit: (item) {
              if (shop != null) {
                showItemEditDialog(original: item, shop: shop);
              }
            },
            onDelete: _handleDelete,
            onRename: (item) {
              if (shop != null) {
                ItemRenameDialog.show(context, item);
              }
            },
            onUpdate: _handleUpdate,
            onReorderInc: _reorderIncItems,
            onReorderCom: _reorderComItems,
            onSortInc: () {
              if (shop != null) showSortDialog(true, shop);
            },
            onSortCom: () {
              if (shop != null) showSortDialog(false, shop);
            },
            onBulkDeleteInc: () {
              if (shop != null) showBulkDeleteDialog(shop, true);
            },
            onBulkDeleteCom: () {
              if (shop != null) showBulkDeleteDialog(shop, false);
            },
            itemListKey: coachItemListKey,
          ),
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                color: theme.scaffoldBackgroundColor,
                child: const AdBanner(),
              ),
              if (shop != null)
                BottomSummaryWidget(
                  shop: shop,
                  onBudgetClick: () => showBudgetDialog(shop),
                  onFab: () => showItemEditDialog(shop: shop),
                  fabKey: coachFabKey,
                  budgetKey: coachBudgetKey,
                ),
            ],
          ),
        );
      },
    );
  }
}
