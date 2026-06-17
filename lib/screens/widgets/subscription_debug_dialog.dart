import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:maikago/services/one_time_purchase_service.dart';
import 'package:maikago/widgets/common_dialog.dart';

/// デバッグ用の購入状態確認ダイアログ（DebugService.enableDebugMode 時のみ使用）
///
/// プレミアム状態・ストア利用可否・エラー情報を表示し、
/// 購入復元ボタンを提供する。
Future<void> showSubscriptionDebugDialog(BuildContext context) {
  return CommonDialog.show(
    context: context,
    builder: (context) => CommonDialog(
      title: 'デバッグ情報',
      content: Consumer<OneTimePurchaseService>(
        builder: (context, service, child) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('まいかごプレミアム: ${service.isPremiumUnlocked}'),
              Text('ストア利用可能: ${service.isStoreAvailable}'),
              if (service.error != null) Text('エラー: ${service.error}'),
            ],
          );
        },
      ),
      actions: [
        CommonDialog.closeButton(context),
        CommonDialog.primaryButton(
          context,
          label: '購入復元',
          onPressed: () async {
            final service =
                Provider.of<OneTimePurchaseService>(context, listen: false);
            await service.restorePurchases();
            if (context.mounted) context.pop();
          },
        ),
      ],
    ),
  );
}
