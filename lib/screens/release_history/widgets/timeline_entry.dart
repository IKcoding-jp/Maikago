import 'package:flutter/material.dart';
import 'package:maikago/models/release_history.dart';
import 'package:maikago/utils/theme_utils.dart';
import 'package:maikago/screens/release_history/widgets/category_section.dart';

/// タイムラインの1エントリ（左にラインとドット、右にカード）
class TimelineEntry extends StatelessWidget {
  const TimelineEntry({
    super.key,
    required this.note,
    required this.isFirst,
    required this.isLast,
    required this.isCurrent,
    required this.primaryColor,
    required this.onPrimaryColor,
  });

  final ReleaseNote note;
  final bool isFirst;
  final bool isLast;
  final bool isCurrent;
  final Color primaryColor;
  final Color onPrimaryColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lineColor = theme.dividerColor;
    final dotColor = isFirst ? primaryColor : lineColor;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // タイムライン（ドット＋ライン）
          SizedBox(
            width: 32,
            child: Column(
              children: [
                // 上のライン
                Container(
                  width: 2,
                  height: 8,
                  color: isFirst ? Colors.transparent : lineColor,
                ),
                // ドット
                Container(
                  width: isFirst ? 14 : 10,
                  height: isFirst ? 14 : 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFirst ? dotColor : Colors.transparent,
                    border: Border.all(
                      color: dotColor,
                      width: isFirst ? 0 : 2,
                    ),
                  ),
                ),
                // 下のライン
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast ? Colors.transparent : lineColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // カード本体
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: _buildCard(context, theme),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, ThemeData theme) {
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: isFirst
            ? Border.all(
                color: primaryColor.withValues(alpha: 0.3),
                width: 1,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ヘッダー
          _buildHeader(context, theme),
          // 変更内容
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _buildChanges(context, theme),
          ),
          // 開発者コメント
          if (note.developerComment != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _buildComment(context, theme, note.developerComment!),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color:
            isFirst ? primaryColor.withValues(alpha: 0.06) : Colors.transparent,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          // バージョン番号
          Text(
            'v${note.version}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(width: 8),
          // バッジ
          if (isCurrent) _buildPill(context, '現在のバージョン', primaryColor),
          if (isFirst && !isCurrent)
            _buildPill(context, '最新', theme.colorScheme.primary),
          const Spacer(),
          // 日付
          Text(
            _formatDate(note.releaseDate),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.subtextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPill(BuildContext context, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
      ),
    );
  }

  Widget _buildChanges(BuildContext context, ThemeData theme) {
    // カテゴリごとにグループ化
    final grouped = <ChangeCategory, List<ChangeItem>>{};
    for (final change in note.changes) {
      grouped.putIfAbsent(change.category, () => []).add(change);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final category in ChangeCategory.values)
          if (grouped.containsKey(category)) ...[
            const SizedBox(height: 10),
            CategorySection(
              category: category,
              items: grouped[category]!,
            ),
          ],
      ],
    );
  }

  Widget _buildComment(BuildContext context, ThemeData theme, String comment) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline_rounded, color: primaryColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              comment,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }
}
