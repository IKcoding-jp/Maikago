import 'package:flutter/material.dart';

/// OCR結果の合計金額サマリーウィジェット
class OcrResultTotalSummary extends StatelessWidget {
  const OcrResultTotalSummary({
    super.key,
    required this.currentTotal,
    required this.diff,
  });

  final int currentTotal;
  final int diff;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final newTotal = currentTotal + diff;
    final sign = diff >= 0 ? '+' : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(
          top: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '現在の合計',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '¥$currentTotal',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '更新後の合計',
                style: theme.textTheme.titleMedium,
              ),
              Row(
                children: [
                  Text(
                    '¥$newTotal',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '($sign¥$diff)',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: diff >= 0
                          ? theme.colorScheme.primary
                          : theme.colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
