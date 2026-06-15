import 'package:flutter/material.dart';
import 'package:maikago/services/settings_theme.dart';
import 'package:maikago/utils/theme_utils.dart';

/// プレミアム画面の機能紹介セクション
class PremiumFeaturesSection extends StatelessWidget {
  const PremiumFeaturesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -30),
      child: Container(
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 0),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'プレミアム機能',
              style: TextStyle(
                fontSize: Theme.of(context).textTheme.displayMedium?.fontSize,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '一度購入すれば、永続的に利用可能',
              style: TextStyle(
                fontSize: Theme.of(context).textTheme.bodyLarge?.fontSize,
                color: Theme.of(context).subtextColor,
              ),
            ),
            const SizedBox(height: 24),

            // 機能一覧
            _buildFeatureItem(
              context,
              icon: Icons.camera_alt,
              title: 'OCR（値札撮影）無制限',
              description: '月5回の制限を解除\n値札を撮って自動入力',
              color: AppColors.featureRed,
            ),
            const SizedBox(height: 20),
            _buildFeatureItem(
              context,
              icon: Icons.store,
              title: 'ショップ（タブ）無制限',
              description: '2つの制限を解除\nお店ごとにリストを管理',
              color: AppColors.featurePremiumBlue,
            ),
            const SizedBox(height: 20),
            _buildFeatureItem(
              context,
              icon: Icons.restaurant_menu,
              title: 'レシピ解析',
              description: 'テキストから\n買い物リストを自動作成',
              color: AppColors.featureMaterialOrange,
            ),
            const SizedBox(height: 20),
            _buildFeatureItem(
              context,
              icon: Icons.palette,
              title: '全テーマ・全フォント',
              description: 'お気に入りのテーマとフォントで\nアプリをカスタマイズ',
              color: AppColors.featurePurple,
            ),
            const SizedBox(height: 20),
            _buildFeatureItem(
              context,
              icon: Icons.block,
              title: '広告完全非表示',
              description: '邪魔な広告なしで\n集中して買い物',
              color: AppColors.featurePremiumGreen,
            ),
          ],
        ),
      ),
    );
  }

  /// 機能アイテム
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
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize:
                      Theme.of(context).textTheme.headlineMedium?.fontSize,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: Theme.of(context).textTheme.bodyMedium?.fontSize,
                  color: Theme.of(context).subtextColor,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
