import 'package:flutter/material.dart';
import 'package:maikago/models/release_history.dart';
import 'package:maikago/services/settings_theme.dart';
import 'package:maikago/utils/theme_utils.dart';
import 'package:maikago/widgets/common_dialog.dart';

/// 新バージョン通知ダイアログ
class VersionUpdateDialog extends StatelessWidget {
  const VersionUpdateDialog({
    super.key,
    required this.latestRelease,
    required this.currentTheme,
    required this.currentFont,
    required this.currentFontSize,
    this.onViewDetails,
    this.onDismiss,
  });

  final ReleaseNote latestRelease;
  final String currentTheme;
  final String currentFont;
  final double currentFontSize;
  final VoidCallback? onViewDetails;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return CommonDialog(
      title: '新機能のお知らせ',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // バージョン情報
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: SettingsTheme.getPrimaryColor(currentTheme),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'v${latestRelease.version}',
              style: TextStyle(
                color: SettingsTheme.getContrastColor(
                  SettingsTheme.getPrimaryColor(currentTheme),
                ),
                fontWeight: FontWeight.bold,
                fontSize: Theme.of(context).textTheme.bodyMedium?.fontSize,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 変更内容のプレビュー（最初の3項目まで）
          Text(
            '主な変更点:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: Theme.of(context).textTheme.bodyLarge?.fontSize,
            ),
          ),
          const SizedBox(height: 8),
          ...latestRelease.changes.take(3).map((change) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6, right: 12),
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _getCategoryColor(context, change.category),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        change.description,
                        style: TextStyle(
                          color: Theme.of(context).subtextColor,
                          fontSize:
                              Theme.of(context).textTheme.bodyMedium?.fontSize,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
          if (latestRelease.changes.length > 3) ...[
            const SizedBox(height: 4),
            Text(
              '他 ${latestRelease.changes.length - 3} 件の変更があります',
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
                fontSize: Theme.of(context).textTheme.bodySmall?.fontSize,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (latestRelease.developerComment != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: SettingsTheme.getPrimaryColor(currentTheme)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: SettingsTheme.getPrimaryColor(currentTheme)
                      .withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: SettingsTheme.getPrimaryColor(currentTheme),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      latestRelease.developerComment!,
                      style: TextStyle(
                        color: Theme.of(context).subtextColor,
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        CommonDialog.closeButton(context, onPressed: onDismiss),
        CommonDialog.primaryButton(context,
            label: '詳しく見る', onPressed: onViewDetails),
      ],
    );
  }

  Color _getCategoryColor(BuildContext context, ChangeCategory category) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (category) {
      case ChangeCategory.newFeature:
        return colorScheme.tertiary;
      case ChangeCategory.bugFix:
        return colorScheme.error;
      case ChangeCategory.improvement:
        return colorScheme.primary;
      case ChangeCategory.other:
        return colorScheme.secondary;
    }
  }
}
