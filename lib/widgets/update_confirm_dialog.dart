import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:maikago/widgets/common_dialog.dart';
import 'package:maikago/utils/snackbar_utils.dart';

/// 更新確認ダイアログ
/// 既存リストを更新する前の最終確認を行う
class UpdateConfirmDialog extends StatefulWidget {
  const UpdateConfirmDialog({
    super.key,
    required this.targetListName,
    required this.currentItemCount,
    required this.newItemCount,
    required this.newTotalPrice,
    required this.onConfirm,
  });

  final String targetListName;
  final int currentItemCount;
  final int newItemCount;
  final int newTotalPrice;
  final Future<void> Function() onConfirm;

  /// ダイアログを表示
  static Future<bool> show({
    required BuildContext context,
    required String targetListName,
    required int currentItemCount,
    required int newItemCount,
    required int newTotalPrice,
    required Future<void> Function() onConfirm,
  }) async {
    final result = await CommonDialog.show<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => UpdateConfirmDialog(
        targetListName: targetListName,
        currentItemCount: currentItemCount,
        newItemCount: newItemCount,
        newTotalPrice: newTotalPrice,
        onConfirm: onConfirm,
      ),
    );
    return result ?? false;
  }

  @override
  State<UpdateConfirmDialog> createState() => _UpdateConfirmDialogState();
}

class _UpdateConfirmDialogState extends State<UpdateConfirmDialog> {
  bool _isProcessing = false;

  Future<void> _handleConfirm() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      await widget.onConfirm();
      if (mounted) {
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        showErrorSnackBar(context, '更新に失敗しました: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CommonDialog(
      title: 'リストを更新',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: theme.textTheme.bodyLarge,
              children: [
                const TextSpan(text: '「'),
                TextSpan(
                  text: widget.targetListName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const TextSpan(text: '」の内容を更新しますか？'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(
                  context,
                  '現在の商品数:',
                  '${widget.currentItemCount}個',
                  Icons.inventory_2_outlined,
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  context,
                  '新しい商品数:',
                  '${widget.newItemCount}個',
                  Icons.add_shopping_cart,
                ),
                const Divider(height: 16),
                _buildInfoRow(
                  context,
                  '新しい合計:',
                  '¥${widget.newTotalPrice}',
                  Icons.payments_outlined,
                  isHighlighted: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '既存の商品に読込内容を反映（追加・更新）します',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        CommonDialog.cancelButton(context,
            onPressed: _isProcessing ? null : () => context.pop(false)),
        CommonDialog.primaryButton(
          context,
          label: '更新する',
          onPressed: _isProcessing ? null : _handleConfirm,
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    bool isHighlighted = false,
  }) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: isHighlighted
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w500,
            color: isHighlighted
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
