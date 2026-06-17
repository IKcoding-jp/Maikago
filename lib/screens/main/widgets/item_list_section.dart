import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'package:maikago/models/list.dart';
import 'package:maikago/models/shop.dart';
import 'package:maikago/screens/main/widgets/empty_state_guide.dart';
import 'package:maikago/widgets/list_edit.dart';

/// メイン画面のアイテムリスト（未購入/購入済み左右分割）
class ItemListSection extends StatelessWidget {
  const ItemListSection({
    super.key,
    required this.shop,
    required this.incItems,
    required this.comItems,
    required this.strikethroughEnabled,
    required this.theme,
    required this.onCheckToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onRename,
    required this.onUpdate,
    required this.onReorderInc,
    required this.onReorderCom,
    required this.onSortInc,
    required this.onSortCom,
    required this.onBulkDeleteInc,
    required this.onBulkDeleteCom,
    this.itemListKey,
  });

  final Shop? shop;
  final List<ListItem> incItems;
  final List<ListItem> comItems;
  final bool strikethroughEnabled;
  final ThemeData theme;
  final void Function(ListItem item, bool checked) onCheckToggle;
  final void Function(ListItem item) onEdit;
  final Future<void> Function(ListItem item) onDelete;
  final void Function(ListItem item) onRename;
  final Future<void> Function(ListItem updatedItem) onUpdate;
  final void Function(int oldIndex, int newIndex) onReorderInc;
  final void Function(int oldIndex, int newIndex) onReorderCom;
  final VoidCallback onSortInc;
  final VoidCallback onSortCom;
  final VoidCallback onBulkDeleteInc;
  final VoidCallback onBulkDeleteCom;
  final GlobalKey? itemListKey;

  @override
  Widget build(BuildContext context) {
    // 両方とも空のときは左右一体ガイド（行単位で左右が揃う）を全幅表示
    if (incItems.isEmpty && comItems.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(left: 8.0, right: 8.0, bottom: 8.0),
        child: EmptyStateGuide(),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 8.0),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: _buildSection(
              context,
              title: '未購入',
              items: incItems,
              onReorder: onReorderInc,
              onSort: onSortInc,
              onBulkDelete: onBulkDeleteInc,
              sortTooltip: '未購入アイテムの並び替え',
              deleteTooltip: '未購入アイテムを一括削除',
              sectionKey: itemListKey,
              isIncomplete: true,
            ),
          ),
          Container(
            width: 1,
            height: 600,
            margin: const EdgeInsets.only(top: 50),
            color: theme.dividerColor,
          ),
          Expanded(
            flex: 1,
            child: _buildSection(
              context,
              title: '購入済み',
              items: comItems,
              onReorder: onReorderCom,
              onSort: onSortCom,
              onBulkDelete: onBulkDeleteCom,
              sortTooltip: '購入済みアイテムの並び替え',
              deleteTooltip: '購入済みアイテムを一括削除',
              isIncomplete: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<ListItem> items,
    required void Function(int, int) onReorder,
    required VoidCallback onSort,
    required VoidCallback onBulkDelete,
    required String sortTooltip,
    required String deleteTooltip,
    GlobalKey? sectionKey,
    required bool isIncomplete,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0, top: 8.0),
          child: Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: theme.textTheme.headlineMedium?.fontSize,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.sort),
                onPressed: onSort,
                tooltip: sortTooltip,
              ),
              IconButton(
                icon: const Icon(Icons.delete_sweep),
                onPressed: onBulkDelete,
                tooltip: deleteTooltip,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          key: sectionKey,
          child: ClipRect(
            child: items.isEmpty
                ? EmptyStateGuidePanel(isIncomplete: isIncomplete)
                : ReorderableListView.builder(
                    padding: EdgeInsets.only(
                      left: 4,
                      right: 4,
                      top: 8,
                      bottom: MediaQuery.of(context).padding.bottom + 8,
                    ),
                    itemCount: items.length,
                    onReorder: onReorder,
                    cacheExtent: 250,
                    physics: const ClampingScrollPhysics(),
                    clipBehavior: Clip.hardEdge,
                    proxyDecorator: (child, index, animation) {
                      return AnimatedBuilder(
                        animation: animation,
                        builder: (context, child) {
                          final animValue =
                              Curves.easeInOut.transform(animation.value);
                          final scale = lerpDouble(1, 1.03, animValue)!;
                          return Transform.scale(
                            scale: scale,
                            child: child,
                          );
                        },
                        child: child,
                      );
                    },
                    itemBuilder: (context, idx) {
                      final item = items[idx];
                      return ListEdit(
                        key: ValueKey(item.id),
                        item: item,
                        strikethroughEnabled: strikethroughEnabled,
                        onCheckToggle: (checked) {
                          onCheckToggle(item, checked);
                        },
                        onEdit: () {
                          if (shop != null) {
                            onEdit(item);
                          }
                        },
                        onDelete: () async {
                          if (shop == null) return;
                          await onDelete(item);
                        },
                        onRename: () {
                          if (shop != null) {
                            onRename(item);
                          }
                        },
                        onUpdate: (updatedItem) async {
                          await onUpdate(updatedItem);
                        },
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
