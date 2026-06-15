import 'package:flutter/material.dart';
import 'package:maikago/models/list.dart';
import 'package:maikago/widgets/common_dialog.dart';
import 'package:maikago/widgets/list_item_edit_dialog.dart';

class ListEdit extends StatefulWidget {
  const ListEdit({
    super.key,
    required this.item,
    required this.onCheckToggle,
    this.onEdit,
    this.onDelete,
    this.onRename,
    this.onUpdate,
    this.showEdit = true,
    this.strikethroughEnabled = false,
  });

  final ListItem item;
  final ValueChanged<bool> onCheckToggle;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onRename;
  final Function(ListItem)? onUpdate;
  final bool showEdit;
  final bool strikethroughEnabled;

  @override
  State<ListEdit> createState() => _ListEditState();
}

class _ListEditState extends State<ListEdit> {
  void _showListItemInputDialog(BuildContext context) {
    CommonDialog.show(
      context: context,
      builder: (BuildContext context) {
        return ListItemEditDialog(
          item: widget.item,
          onUpdate: widget.onUpdate,
          onDelete: widget.onDelete,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return RepaintBoundary(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: theme.dividerColor,
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.10),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: Row(
                children: [
                  Container(
                    width: 5,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.7),
                    ),
                  ),
                  Expanded(
                    child: Dismissible(
                      key: ValueKey(widget.item.id),
                      direction: DismissDirection.horizontal,
                      resizeDuration: const Duration(milliseconds: 200),
                      movementDuration: const Duration(milliseconds: 200),
                      dismissThresholds: const {
                        DismissDirection.horizontal: 0.3,
                      },
                      background: Container(
                        decoration: BoxDecoration(
                          color: widget.item.isChecked
                              ? colorScheme.tertiary
                                  .withValues(alpha: 0.8) // 未購入に戻す色
                              : colorScheme.primary
                                  .withValues(alpha: 0.8), // 購入済みに移動する色
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 20),
                        child: Icon(
                          widget.item.isChecked ? Icons.undo : Icons.check,
                          color: colorScheme.onPrimary,
                          size: 28,
                        ),
                      ),
                      secondaryBackground: Container(
                        decoration: BoxDecoration(
                          color: widget.item.isChecked
                              ? colorScheme.tertiary
                                  .withValues(alpha: 0.8) // 未購入に戻す色
                              : colorScheme.primary
                                  .withValues(alpha: 0.8), // 購入済みに移動する色
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: Icon(
                          widget.item.isChecked ? Icons.undo : Icons.check,
                          color: colorScheme.onPrimary,
                          size: 28,
                        ),
                      ),
                      confirmDismiss: (direction) async {
                        // スライドでチェック状態を切り替え
                        widget.onCheckToggle(!widget.item.isChecked);
                        return false; // アイテムを削除しない
                      },
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _showListItemInputDialog(context),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          child: IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      if (widget.item.isRecipeOrigin)
                                        Container(
                                          margin:
                                              const EdgeInsets.only(bottom: 4),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: colorScheme.secondary
                                                .withValues(alpha: 0.2),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                            border: Border.all(
                                                color: colorScheme.secondary,
                                                width: 0.5),
                                          ),
                                          child: Text(
                                            (widget.item.recipeName != null &&
                                                    widget.item.recipeName!
                                                        .isNotEmpty)
                                                ? widget.item.recipeName!
                                                : 'レシピ由来',
                                            style: TextStyle(
                                              fontSize: Theme.of(context)
                                                  .textTheme
                                                  .labelSmall
                                                  ?.fontSize,
                                              color: colorScheme.primary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      Center(
                                        child: Text(
                                          widget.item.name,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: (widget.item.isChecked &&
                                                    widget.strikethroughEnabled)
                                                ? colorScheme.outline
                                                : colorScheme.onSurface,
                                            decoration: (widget
                                                        .item.isChecked &&
                                                    widget.strikethroughEnabled)
                                                ? TextDecoration.lineThrough
                                                : null,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 2,
                                          softWrap: true,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Center(
                                        child: Wrap(
                                          spacing: 8,
                                          alignment: WrapAlignment.center,
                                          runAlignment: WrapAlignment.center,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            if (widget.item.discount > 0) ...[
                                              Text(
                                                '¥${widget.item.price}',
                                                style: TextStyle(
                                                  color: colorScheme.onSurface
                                                      .withValues(
                                                    alpha: 0.7,
                                                  ),
                                                  decoration: TextDecoration
                                                      .lineThrough,
                                                ),
                                              ),
                                              Text(
                                                '¥${(widget.item.price * (1 - widget.item.discount)).round()}',
                                                style: TextStyle(
                                                  color: colorScheme.error,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ] else
                                              Text(
                                                '¥${widget.item.price}',
                                                style: TextStyle(
                                                    color:
                                                        colorScheme.onSurface),
                                              ),
                                            Text(
                                              '×${widget.item.quantity}',
                                              style: TextStyle(
                                                  color: colorScheme.onSurface),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
