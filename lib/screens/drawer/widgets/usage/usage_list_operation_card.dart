import 'package:flutter/material.dart';
import 'package:maikago/services/settings_theme.dart';
import 'package:maikago/utils/theme_utils.dart';

class UsageListOperationCard extends StatelessWidget {
  const UsageListOperationCard({super.key});

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
            'リストアイテムの操作方法',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // タップ操作
          _buildOperationItem(
            context,
            icon: Icons.touch_app_rounded,
            title: 'タップ',
            description: '商品の編集・削除',
            details:
                'リストアイテムをタップすると、商品の編集画面が開きます。個数、単価、割引率の設定、商品名の変更、削除がすべてこの画面で行えます。',
            color: AppColors.featureMaterialGreen,
          ),
          const SizedBox(height: 16),

          // スワイプ操作
          _buildOperationItem(
            context,
            icon: Icons.swipe_rounded,
            title: 'スワイプ',
            description: '未購入と購入済みの移動',
            details:
                'リストアイテムを左右にスワイプすると、未購入と購入済みの間で移動できます。購入済みに移動すると合計金額が自動計算されます。',
            color: AppColors.featureMaterialBlue,
          ),
          const SizedBox(height: 16),

          // 長押し操作
          _buildOperationItem(
            context,
            icon: Icons.drag_indicator_rounded,
            title: '長押し',
            description: 'リストの並べ替え',
            details: 'リストアイテムを長押しすると並べ替えモードになります。ドラッグして好きな順番に並べ替えることができます。',
            color: AppColors.featureMaterialOrange,
          ),
        ],
      ),
    );
  }

  Widget _buildOperationItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required String details,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        description,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  details,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.7),
                        height: 1.4,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
