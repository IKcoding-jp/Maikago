import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:maikago/models/shop.dart';
import 'package:maikago/utils/calculation_utils.dart';
import 'package:maikago/widgets/common_dialog.dart';

/// 既存リスト選択ダイアログ
/// OCR結果で更新するリストを選択する
class ExistingListSelectorDialog extends StatelessWidget {
  const ExistingListSelectorDialog({
    super.key,
    required this.shops,
    required this.onShopSelected,
    this.currentShopId,
  });

  final List<Shop> shops;
  final String? currentShopId;
  final void Function(Shop shop) onShopSelected;

  /// ダイアログを表示
  static Future<Shop?> show({
    required BuildContext context,
    required List<Shop> shops,
    String? currentShopId,
  }) async {
    final result = await CommonDialog.show<Shop>(
      context: context,
      builder: (context) => ExistingListSelectorDialog(
        shops: shops,
        currentShopId: currentShopId,
        onShopSelected: (shop) => context.pop(shop),
      ),
    );
    return result;
  }

  /// 日付を簡易フォーマット
  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CommonDialog(
      title: '更新するリストを選択',
      content: SizedBox(
        width: double.maxFinite,
        child: shops.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 48,
                      color: theme.colorScheme.outline,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'リストがありません',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.separated(
                shrinkWrap: true,
                itemCount: shops.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final shop = shops[index];
                  final isCurrent = shop.id == currentShopId;
                  final itemCount = shop.items.length;
                  final totalPrice = _calculateTotalPrice(shop);
                  final lastUpdated = shop.createdAt;

                  return ListTile(
                    onTap: () => onShopSelected(shop),
                    leading: CircleAvatar(
                      backgroundColor: isCurrent
                          ? theme.colorScheme.primaryContainer
                          : theme.colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.shopping_bag_outlined,
                        color: isCurrent
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            shop.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isCurrent)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '現在',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _buildChip(
                              context,
                              Icons.inventory_2_outlined,
                              '$itemCount個',
                            ),
                            const SizedBox(width: 8),
                            _buildChip(
                              context,
                              Icons.payments_outlined,
                              '¥$totalPrice',
                            ),
                          ],
                        ),
                        if (lastUpdated != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '更新: ${_formatDate(lastUpdated)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ],
                      ],
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: theme.colorScheme.outline,
                    ),
                  );
                },
              ),
      ),
      actions: [
        CommonDialog.cancelButton(context),
      ],
    );
  }

  Widget _buildChip(BuildContext context, IconData icon, String label) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  int _calculateTotalPrice(Shop shop) =>
      calcShopTotal(shop, checkedOnly: false);
}
