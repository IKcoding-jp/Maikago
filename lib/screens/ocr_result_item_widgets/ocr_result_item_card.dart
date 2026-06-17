import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:maikago/models/ocr_session_result.dart';
import 'package:maikago/models/list.dart';

/// OCR結果アイテムカード
///
/// 1つのOCRアイテムを表示・編集するカード。マッチング情報の表示、
/// 商品名・価格・数量の編集、上書き/新規追加の切り替え、紐付けボタンを含む。
class OcrResultItemCard extends StatelessWidget {
  const OcrResultItemCard({
    super.key,
    required this.item,
    required this.index,
    this.matchedItem,
    required this.isOverwrite,
    required this.onItemChanged,
    required this.onRemove,
    required this.onOverwriteChanged,
    required this.onUnlinkMatch,
    required this.onLinkExistingItem,
  });

  final OcrSessionResultItem item;
  final int index;
  final ListItem? matchedItem;
  final bool isOverwrite;
  final ValueChanged<OcrSessionResultItem> onItemChanged;
  final VoidCallback onRemove;
  final ValueChanged<bool> onOverwriteChanged;
  final VoidCallback onUnlinkMatch;
  final VoidCallback onLinkExistingItem;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: matchedItem != null
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: Column(
        children: [
          // マッチングエリア
          if (matchedItem != null) _buildMatchSection(context, theme),

          // OCR結果（編集エリア）
          _buildEditSection(context, theme),

          // 紐付けボタン（マッチしていない場合のみ）
          if (matchedItem == null) _buildLinkButton(theme),
        ],
      ),
    );
  }

  /// マッチング情報セクション
  Widget _buildMatchSection(BuildContext context, ThemeData theme) {
    return Column(
      children: [
        Container(
          color:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.verified_outlined,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '既存の商品が見つかりました',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: onUnlinkMatch,
                    child: Text(
                      '解除',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.error,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 既存商品情報
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        matchedItem!.name,
                        style: theme.textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '¥${matchedItem!.price}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
        // 矢印（マッチング枠の下）
        Container(
          color: theme.colorScheme.surfaceContainerHighest,
          padding: const EdgeInsets.symmetric(vertical: 4),
          width: double.infinity,
          child: Icon(
            Icons.arrow_downward,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// 編集セクション（商品名・価格・数量）
  Widget _buildEditSection(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // 商品名
          TextFormField(
            initialValue: item.name,
            maxLength: 150,
            buildCounter: (context,
                    {required currentLength, required isFocused, maxLength}) =>
                null,
            decoration: const InputDecoration(
              labelText: '読み取り商品名',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onChanged: (value) {
              onItemChanged(item.copyWith(name: value));
            },
          ),
          const SizedBox(height: 12),
          // 価格と数量
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  initialValue: item.price.toString(),
                  maxLength: 8,
                  buildCounter: (context,
                          {required currentLength,
                          required isFocused,
                          maxLength}) =>
                      null,
                  decoration: const InputDecoration(
                    labelText: '価格',
                    prefixText: '¥',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (value) {
                    final price = int.tryParse(value) ?? 0;
                    onItemChanged(item.copyWith(price: price));
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  initialValue: item.quantity.toString(),
                  maxLength: 3,
                  buildCounter: (context,
                          {required currentLength,
                          required isFocused,
                          maxLength}) =>
                      null,
                  decoration: const InputDecoration(
                    labelText: '数量',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (value) {
                    final quantity = int.tryParse(value) ?? 1;
                    onItemChanged(
                        item.copyWith(quantity: quantity.clamp(1, 99)));
                  },
                ),
              ),
              const SizedBox(width: 8),
              // 削除ボタン
              IconButton(
                onPressed: onRemove,
                icon: Icon(
                  Icons.delete_outline,
                  color: theme.colorScheme.error,
                ),
                tooltip: '削除',
              ),
            ],
          ),
          // 上書きスイッチ（マッチしている場合のみ）
          if (matchedItem != null) ...[
            const SizedBox(height: 12),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  isOverwrite ? '上書き更新' : '別に追加',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: isOverwrite
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: isOverwrite,
                  onChanged: onOverwriteChanged,
                  activeTrackColor: theme.colorScheme.primary,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// 紐付けボタン
  Widget _buildLinkButton(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Center(
        child: TextButton.icon(
          onPressed: onLinkExistingItem,
          icon: const Icon(Icons.link, size: 20),
          label: const Text('既存の商品と紐付ける'),
          style: TextButton.styleFrom(
            foregroundColor: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
