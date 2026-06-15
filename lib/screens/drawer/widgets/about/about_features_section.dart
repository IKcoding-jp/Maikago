import 'package:flutter/material.dart';
import 'package:maikago/services/settings_theme.dart';

/// アプリについて画面の特徴セクション
/// アプリの主要機能を紹介
class AboutFeaturesSection extends StatelessWidget {
  const AboutFeaturesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.star_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'アプリの特徴',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildFeatureItem(
              context,
              icon: Icons.check_circle_rounded,
              title: 'シンプルで使いやすい',
              description: '直感的な操作で、誰でも簡単に使えます',
              color: AppColors.featureMaterialGreen,
            ),
            const SizedBox(height: 16),
            _buildFeatureItem(
              context,
              icon: Icons.calculate_rounded,
              title: '自動計算機能',
              description: 'メモと電卓が一体化し、リアルタイムで合計金額を計算',
              color: AppColors.featureMaterialBlue,
            ),
            const SizedBox(height: 16),
            _buildFeatureItem(
              context,
              icon: Icons.savings_rounded,
              title: '予算管理',
              description: '予算を設定して、買い物の予算オーバーを防止',
              color: AppColors.featureMaterialOrange,
            ),
            const SizedBox(height: 16),
            _buildFeatureItem(
              context,
              icon: Icons.sort_rounded,
              title: '整理整頓',
              description: 'アイテムの並び替えや一括削除で、リストをすっきり管理',
              color: AppColors.featurePurple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.7),
                      height: 1.4,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
