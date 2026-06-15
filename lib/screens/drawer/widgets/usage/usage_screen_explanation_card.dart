import 'package:flutter/material.dart';
import 'package:maikago/utils/theme_utils.dart';

class UsageScreenExplanationCard extends StatelessWidget {
  const UsageScreenExplanationCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).cardShadowColor,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '画面の構成',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildScreenElement(
            context,
            icon: Icons.tab_rounded,
            title: 'タブ',
            description: '画面上部に表示されるタブです。複数のタブを作成できます。',
          ),
          const SizedBox(height: 12),
          _buildScreenElement(
            context,
            icon: Icons.list_alt_rounded,
            title: '未購入リスト',
            description: '各タブ内に表示される未購入の商品一覧です。購入予定の商品がチェックボックス付きで表示されます。',
          ),
          const SizedBox(height: 12),
          _buildScreenElement(
            context,
            icon: Icons.check_circle_outline_rounded,
            title: '購入済みリスト',
            description: 'チェックした商品が移動する場所です。合計金額が自動計算されます。',
          ),
          const SizedBox(height: 12),
          _buildScreenElement(
            context,
            icon: Icons.account_balance_wallet_rounded,
            title: '予算設定',
            description: '各タブに予算を設定できます。残り予算が表示され、予算を超えると警告が表示されます。',
          ),
          const SizedBox(height: 12),
          _buildScreenElement(
            context,
            icon: Icons.attach_money_rounded,
            title: '合計金額表示',
            description: '画面下部に表示される購入済み商品の合計金額です。',
          ),
          const SizedBox(height: 12),
          _buildScreenElement(
            context,
            icon: Icons.camera_alt_rounded,
            title: 'カメラボタン',
            description: '画面下部の真ん中のカメラボタンをタップして、値札撮影で商品を自動追加できます。',
          ),
        ],
      ),
    );
  }

  Widget _buildScreenElement(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon,
              color: Theme.of(context).colorScheme.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                description,
                style: Theme.of(
                  context,
                )
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).subtextColor),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
