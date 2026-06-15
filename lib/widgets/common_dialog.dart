import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:maikago/utils/dialog_utils.dart';
import 'package:maikago/utils/theme_utils.dart';

/// 共通ダイアログ基盤ウィジェット
///
/// 統一されたスタイル（角丸20px、テーマカラードットタイトル、一貫したボタン）を提供。
/// 各ダイアログはこのウィジェットをシェルとして使い、contentとactionsを渡す。
class CommonDialog extends StatelessWidget {
  const CommonDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
    this.insetPadding,
    this.contentPadding,
  });

  final String title;
  final Widget content;
  final List<Widget> actions;
  final EdgeInsets? insetPadding;
  final EdgeInsets? contentPadding;

  /// showConstrainedDialog ラッパー
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
  }) {
    return showConstrainedDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: builder,
    );
  }

  // ---------------------------------------------------------------------------
  // ボタンヘルパー
  // ---------------------------------------------------------------------------

  /// キャンセルボタン（テキスト、onSurface色）
  static Widget cancelButton(
    BuildContext context, {
    String label = 'キャンセル',
    VoidCallback? onPressed,
  }) {
    final theme = Theme.of(context);
    return TextButton(
      onPressed: onPressed ?? () => context.pop(),
      style: TextButton.styleFrom(
        foregroundColor: theme.colorScheme.onSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: Text(label),
    );
  }

  /// メインアクションボタン（テーマカラー背景、角丸20px）
  static Widget primaryButton(
    BuildContext context, {
    required String label,
    required VoidCallback? onPressed,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 0,
      ),
      child: Text(label),
    );
  }

  /// 危険アクションボタン（赤テキスト）
  static Widget destructiveButton(
    BuildContext context, {
    String label = '削除',
    required VoidCallback onPressed,
  }) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.error,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: Text(label),
    );
  }

  /// 閉じるボタン（テキスト、onSurface色）
  static Widget closeButton(
    BuildContext context, {
    String label = '閉じる',
    VoidCallback? onPressed,
  }) {
    return cancelButton(context, label: label, onPressed: onPressed);
  }

  // ---------------------------------------------------------------------------
  // ローディングダイアログ
  // ---------------------------------------------------------------------------

  /// ローディング中の統一されたダイアログ
  static Widget loading(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: theme.cardColor,
      content: const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TextField デコレーションヘルパー
  // ---------------------------------------------------------------------------

  /// 統一されたTextFieldデコレーション
  static InputDecoration textFieldDecoration(
    BuildContext context, {
    String? labelText,
    String? hintText,
    String? helperText,
    String? prefixText,
    String? suffixText,
  }) {
    final theme = Theme.of(context);

    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      helperText: helperText,
      helperStyle: theme.textTheme.bodySmall?.copyWith(
        color: theme.subtextColor,
      ),
      prefixText: prefixText,
      suffixText: suffixText,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: theme.dividerColor,
          width: 1.5,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: theme.colorScheme.primary,
          width: 2,
        ),
      ),
      fillColor: theme.cardColor,
      filled: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: theme.cardColor,
      insetPadding: insetPadding ??
          const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      contentPadding:
          contentPadding ?? const EdgeInsets.fromLTRB(24, 16, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      title: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: content,
      actions: actions,
    );
  }
}
