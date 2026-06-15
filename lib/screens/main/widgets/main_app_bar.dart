import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:maikago/models/shop.dart';

import 'package:maikago/providers/data_provider.dart';
import 'package:maikago/screens/main/utils/ui_calculations.dart';
import 'package:maikago/utils/theme_utils.dart';

/// メイン画面のAppBar（タブ表示＋追加ボタン）
class MainAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MainAppBar({
    super.key,
    required this.sortedShops,
    required this.selectedIndex,
    required this.currentTheme,
    required this.customColors,
    required this.theme,
    required this.scaffoldBgLuminance,
    required this.onTabTap,
    required this.onTabLongPress,
    required this.onAddTab,
    this.addTabKey,
  });

  final List<Shop> sortedShops;
  final int selectedIndex;
  final String currentTheme;
  final Map<String, Color> customColors;
  final ThemeData theme;
  final double scaffoldBgLuminance;
  final void Function(int index) onTabTap;
  final void Function(int originalIndex) onTabLongPress;
  final VoidCallback onAddTab;
  final GlobalKey? addTabKey;

  double get _fontSize => theme.textTheme.bodyMedium?.fontSize ?? 16.0;

  @override
  Size get preferredSize => Size.fromHeight(
      MainScreenCalculations.calculateTabHeight(_fontSize) + 16);

  @override
  Widget build(BuildContext context) {
    final tabHeight = MainScreenCalculations.calculateTabHeight(_fontSize);
    final tabPadding = MainScreenCalculations.calculateTabPadding(_fontSize);
    final maxLines = MainScreenCalculations.calculateMaxLines(_fontSize);

    return AppBar(
      toolbarHeight: tabHeight + 16,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarIconBrightness:
            scaffoldBgLuminance > 0.5 ? Brightness.dark : Brightness.light,
        statusBarBrightness:
            scaffoldBgLuminance > 0.5 ? Brightness.light : Brightness.dark,
        systemNavigationBarIconBrightness: theme.brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
      ),
      title: Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          height: tabHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: sortedShops.length,
            itemBuilder: (context, index) =>
                _buildTabItem(context, index, tabPadding, maxLines),
          ),
        ),
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      foregroundColor: theme.colorScheme.onSurface,
      elevation: 0,
      surfaceTintColor: theme.colorScheme.surface.withValues(alpha: 0),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: InkWell(
            key: addTabKey,
            onTap: onAddTab,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.add,
                    size: 18,
                    color: theme.subtextColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'タブ追加',
                    style: TextStyle(
                      color: theme.subtextColor,
                      fontSize: _fontSize * 0.8,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabItem(
    BuildContext context,
    int index,
    double tabPadding,
    int maxLines,
  ) {
    final shop = sortedShops[index];
    final isSelected = index == selectedIndex;
    final dataProvider = context.read<DataProvider>();

    // 前後のショップと同じグループか判定
    final prevShop = index > 0 ? sortedShops[index - 1] : null;
    final nextShop =
        index < sortedShops.length - 1 ? sortedShops[index + 1] : null;

    final isSameGroupAsPrev = shop.sharedTabGroupId != null &&
        prevShop?.sharedTabGroupId == shop.sharedTabGroupId;
    final isSameGroupAsNext = shop.sharedTabGroupId != null &&
        nextShop?.sharedTabGroupId == shop.sharedTabGroupId;

    // ボーダーラディウスの決定
    BorderRadius borderRadius;
    if (isSameGroupAsPrev && isSameGroupAsNext) {
      borderRadius = BorderRadius.zero;
    } else if (isSameGroupAsPrev) {
      borderRadius = const BorderRadius.horizontal(right: Radius.circular(20));
    } else if (isSameGroupAsNext) {
      borderRadius = const BorderRadius.horizontal(left: Radius.circular(20));
    } else {
      borderRadius = BorderRadius.circular(20);
    }

    final margin = isSameGroupAsNext
        ? const EdgeInsets.only(right: 1)
        : const EdgeInsets.only(right: 8);

    return GestureDetector(
      onLongPress: () {
        final originalIndex =
            dataProvider.shops.indexWhere((s) => s.id == shop.id);
        if (originalIndex != -1) {
          onTabLongPress(originalIndex);
        }
      },
      onTap: () => onTabTap(index),
      child: Container(
        margin: margin,
        padding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: tabPadding,
        ),
        decoration: BoxDecoration(
          color: _getTabColor(isSelected, shop),
          borderRadius: borderRadius,
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.surface.withValues(alpha: 0)
                : theme.dividerColor,
            width: shop.sharedTabGroupId != null ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _getTabColor(true, shop).withValues(alpha: 0.30),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                shop.name,
                style: TextStyle(
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.subtextColor,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: _fontSize,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: maxLines,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getTabColor(bool isSelected, Shop shop) {
    if (isSelected) {
      if (currentTheme == 'custom' && customColors.containsKey('tabColor')) {
        return customColors['tabColor']!;
      }
      return theme.colorScheme.primary;
    }

    if (shop.sharedTabGroupId != null) {
      return theme.colorScheme.primary
          .withValues(alpha: currentTheme == 'dark' ? 0.2 : 0.1);
    }

    return theme.cardColor;
  }
}
