import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:maikago/widgets/common_dialog.dart';

/// プレミアムアップグレード誘導ダイアログ（汎用）
///
/// OCR、ショップ、レシピ、同期タブなど、
/// 各種機能制限に達した際に表示する共通ダイアログ。
class PremiumUpgradeDialog extends StatelessWidget {
  const PremiumUpgradeDialog({
    super.key,
    required this.title,
    required this.message,
    this.onUpgrade,
  });

  final String title;
  final String message;
  final VoidCallback? onUpgrade;

  /// ダイアログを表示するユーティリティメソッド
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String message,
    VoidCallback? onUpgrade,
  }) {
    return CommonDialog.show(
      context: context,
      builder: (context) => PremiumUpgradeDialog(
        title: title,
        message: message,
        onUpgrade: onUpgrade,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CommonDialog(
      title: title,
      content: Text(message),
      actions: [
        CommonDialog.closeButton(context),
        CommonDialog.primaryButton(context, label: 'プレミアムにアップグレード',
            onPressed: () {
          context.pop();
          onUpgrade?.call();
        }),
      ],
    );
  }
}
