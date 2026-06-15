import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:maikago/services/one_time_purchase_service.dart';
import 'package:maikago/utils/snackbar_utils.dart';
import 'package:maikago/screens/drawer/widgets/premium/premium_hero_section.dart';
import 'package:maikago/screens/drawer/widgets/premium/premium_features_section.dart';
import 'package:maikago/screens/drawer/widgets/premium/premium_purchase_section.dart';
import 'package:maikago/screens/drawer/widgets/premium/premium_trust_section.dart';

/// 非消耗型アプリ内課金画面（旧サブスクリプションプラン選択画面）
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'まいかごプレミアム',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: Theme.of(context).textTheme.headlineLarge?.fontSize,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          // 購入状態復元ボタン
          Consumer<OneTimePurchaseService>(
            builder: (context, service, child) {
              return IconButton(
                icon: const Icon(Icons.restore),
                color: Theme.of(context).colorScheme.onPrimary,
                onPressed: service.isLoading
                    ? null
                    : () => _restorePurchases(context, service),
                tooltip: '購入状態を復元',
              );
            },
          ),
        ],
      ),
      body: Consumer<OneTimePurchaseService>(
        builder: (context, purchaseService, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 50), // 3ボタンナビゲーション分の余白を追加
            child: Column(
              children: [
                // ヒーローセクション
                const PremiumHeroSection(),

                // プレミアム機能セクション
                const PremiumFeaturesSection(),

                // 購入セクション
                PremiumPurchaseSection(purchaseService: purchaseService),

                // 安心・安全セクション
                const PremiumTrustSection(),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 購入状態を復元
  Future<void> _restorePurchases(
      BuildContext context, OneTimePurchaseService service) async {
    try {
      await service.restorePurchases();

      if (context.mounted) {
        showSuccessSnackBar(context, '購入状態を復元しました',
            duration: const Duration(seconds: 2));
      }
    } catch (e) {
      if (context.mounted) {
        showErrorSnackBar(context, '復元に失敗しました: ${e.toString()}');
      }
    }
  }
}
