import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:maikago/services/feature_access_control.dart';
import 'package:maikago/services/one_time_purchase_service.dart';
import 'package:go_router/go_router.dart';
import 'package:maikago/services/settings_theme.dart';
import 'package:maikago/utils/theme_utils.dart';

/// 買い切り型アプリ内課金のアップグレード促進UIシステム
/// 使用状況に基づく推奨プラン表示と魅力的な特典説明を提供
class UpgradePromotionWidget extends StatelessWidget {
  const UpgradePromotionWidget({
    super.key,
    this.title,
    this.description,
    this.blockedFeature,
    this.onUpgrade,
    this.showFullScreen = false,
    this.showCompact = false,
  });

  final String? title;
  final String? description;
  final FeatureType? blockedFeature;
  final VoidCallback? onUpgrade;
  final bool showFullScreen;
  final bool showCompact;

  @override
  Widget build(BuildContext context) {
    return Consumer2<OneTimePurchaseService, FeatureAccessControl>(
      builder: (context, purchaseService, featureControl, _) {
        final isPremiumUnlocked = purchaseService.isPremiumUnlocked;

        // すでにプレミアム機能を利用中の場合は何も表示しない
        if (isPremiumUnlocked) {
          return const SizedBox.shrink();
        }

        if (showFullScreen) {
          return _buildFullScreenPromotion(context);
        } else if (showCompact) {
          return _buildCompactPromotion(context);
        } else {
          return _buildStandardPromotion(context);
        }
      },
    );
  }

  /// 標準的なアップグレード促進表示
  Widget _buildStandardPromotion(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.promoPink, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
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
          Row(
            children: [
              Icon(
                Icons.star,
                color: Theme.of(context).colorScheme.onPrimary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                title ?? 'まいかごプレミアム',
                style: TextStyle(
                  fontSize:
                      Theme.of(context).textTheme.headlineMedium?.fontSize,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description ?? 'すべてのプレミアム機能を利用可能に',
            style: TextStyle(
              fontSize: Theme.of(context).textTheme.bodyMedium?.fontSize,
              color: Theme.of(context).colorScheme.onPrimary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          _buildFeatureList(context),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onUpgrade ?? () => _navigateToPremium(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.surface,
                foregroundColor: AppColors.promoPink,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'プレミアム機能を確認',
                style: TextStyle(
                  fontSize: Theme.of(context).textTheme.bodyLarge?.fontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// コンパクトなアップグレード促進表示
  Widget _buildCompactPromotion(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.promoPink.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.promoPink.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.star,
            color: AppColors.promoPink,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title ?? 'プレミアム機能でより快適に',
              style: TextStyle(
                fontSize: Theme.of(context).textTheme.bodyMedium?.fontSize,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          TextButton(
            onPressed: onUpgrade ?? () => _navigateToPremium(context),
            child: Text(
              '詳細',
              style: TextStyle(
                fontSize: Theme.of(context).textTheme.bodyMedium?.fontSize,
                fontWeight: FontWeight.bold,
                color: AppColors.promoPink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// フルスクリーンのアップグレード促進表示
  Widget _buildFullScreenPromotion(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.promoPink, AppColors.primary],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star,
            color: Theme.of(context).colorScheme.onPrimary,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            title ?? 'まいかごプレミアム',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            description ?? 'すべてのプレミアム機能を利用可能に',
            style: TextStyle(
              fontSize: Theme.of(context).textTheme.bodyLarge?.fontSize,
              color: Theme.of(context).colorScheme.onPrimary,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _buildFeatureList(context),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onUpgrade ?? () => _navigateToPremium(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    foregroundColor: AppColors.promoPink,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'プレミアム機能を確認',
                    style: TextStyle(
                      fontSize: Theme.of(context).textTheme.bodyLarge?.fontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 機能一覧を表示
  Widget _buildFeatureList(BuildContext context) {
    final features = [
      '全テーマ利用可能',
      '全フォント利用可能',
      '広告完全非表示',
    ];

    return Column(
      children: features
          .map((feature) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 16,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      feature,
                      style: TextStyle(
                        fontSize:
                            Theme.of(context).textTheme.bodyMedium?.fontSize,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }

  /// プレミアム画面に遷移
  void _navigateToPremium(BuildContext context) {
    context.push('/subscription');
  }
}
