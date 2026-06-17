import 'package:flutter/material.dart';
import 'package:maikago/utils/theme_utils.dart';

/// 予算・合計金額の詳細表示ウィジェット
/// 予算カード内の残り予算・合計金額を表示する
class BottomSummaryDetails extends StatelessWidget {
  const BottomSummaryDetails({
    super.key,
    required this.total,
    required this.budget,
    required this.over,
    required this.remainingBudget,
    required this.isNegative,
    required this.isSharedMode,
    this.currentTabTotal,
  });

  final int total;
  final int? budget;
  final bool over;
  final int? remainingBudget;
  final bool isNegative;
  final bool isSharedMode;
  final int? currentTabTotal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.dividerColor,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 100,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              // 左側の表示（予算情報）
              Expanded(
                child: _buildBudgetDisplay(theme, colorScheme),
              ),
              // 区切り線
              Container(
                width: 1,
                height: 60,
                color: theme.dividerColor,
              ),
              // 右側の表示（合計金額）
              Expanded(
                child: isSharedMode && currentTabTotal != null
                    ? _buildSharedModeTotalDisplay(theme, colorScheme)
                    : _buildSingleModeTotalDisplay(theme, colorScheme),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 予算情報の表示（左側）
  Widget _buildBudgetDisplay(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          budget != null
              ? (isSharedMode ? '同期残り予算' : '残り予算')
              : (isSharedMode ? '同期予算' : '予算'),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.subtextColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          budget != null ? '¥${remainingBudget.toString()}' : '未設定',
          style: theme.textTheme.headlineMedium?.copyWith(
            color: budget != null && isNegative
                ? colorScheme.error
                : colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (over)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SizedBox(
                  width: constraints.maxWidth,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '⚠ 予算を超えています！',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  /// 同期モードの合計表示
  Widget _buildSharedModeTotalDisplay(
      ThemeData theme, ColorScheme colorScheme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // 1行目: 現在のタブの合計
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              '現在のタブ',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.subtextColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '¥$currentTabTotal',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 2行目: 同期タブ全体の合計
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              '同期合計',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.subtextColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '¥$total',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 通常モードの合計表示
  Widget _buildSingleModeTotalDisplay(
      ThemeData theme, ColorScheme colorScheme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '合計金額',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.subtextColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '¥$total',
          style: theme.textTheme.headlineLarge?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
