import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:maikago/models/one_time_purchase.dart';
import 'package:maikago/services/one_time_purchase_service.dart';
import 'package:maikago/utils/snackbar_utils.dart';
import 'package:maikago/utils/theme_utils.dart';

/// 非消耗型アプリ内課金画面
class OneTimePurchaseScreen extends StatefulWidget {
  const OneTimePurchaseScreen({super.key});

  @override
  State<OneTimePurchaseScreen> createState() => _OneTimePurchaseScreenState();
}

class _OneTimePurchaseScreenState extends State<OneTimePurchaseScreen>
    with WidgetsBindingObserver {
  bool _isLoading = false;

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
      appBar: AppBar(
        title: const Text('プレミアム機能'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: Consumer<OneTimePurchaseService>(
        builder: (context, purchaseService, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ヘッダーセクション
                _buildHeaderSection(),
                const SizedBox(height: 24),

                // 現在の購入状況
                _buildCurrentStatusSection(purchaseService),
                const SizedBox(height: 24),

                // 購入可能な商品一覧
                _buildPurchaseSection(purchaseService),
                const SizedBox(height: 24),

                // エラーメッセージ
                if (purchaseService.error != null)
                  _buildErrorSection(purchaseService.error!),

                // ローディング表示
                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// ヘッダーセクション
  Widget _buildHeaderSection() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary,
            colorScheme.primary.withValues(alpha: 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'プレミアム機能をアンロック',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: colorScheme.onPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '一度購入すれば、永続的に利用可能',
            style: TextStyle(
              fontSize: theme.textTheme.bodyLarge?.fontSize,
              color: colorScheme.onPrimary.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  /// 現在の購入状況セクション
  Widget _buildCurrentStatusSection(OneTimePurchaseService purchaseService) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '現在の購入状況',
              style: TextStyle(
                fontSize: theme.textTheme.headlineMedium?.fontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildStatusItem(
              'まいかごプレミアム',
              purchaseService.isPremiumUnlocked,
              Icons.star,
            ),
          ],
        ),
      ),
    );
  }

  /// ステータスアイテム
  Widget _buildStatusItem(String title, bool isUnlocked, IconData icon) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isUnlocked ? Icons.check_circle : Icons.circle_outlined,
            color: isUnlocked ? colorScheme.primary : colorScheme.outline,
            size: 20,
          ),
          const SizedBox(width: 8),
          Icon(
            icon,
            size: 20,
            color: isUnlocked ? colorScheme.primary : colorScheme.outline,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: theme.textTheme.bodyLarge?.fontSize,
              color: isUnlocked ? colorScheme.onSurface : colorScheme.outline,
              fontWeight: isUnlocked ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
          if (isUnlocked) ...[
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '購入済み',
                style: TextStyle(
                  color: colorScheme.onPrimary,
                  fontSize: theme.textTheme.bodySmall?.fontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 購入セクション
  Widget _buildPurchaseSection(OneTimePurchaseService purchaseService) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '購入可能な機能',
          style: TextStyle(
            fontSize: theme.textTheme.headlineMedium?.fontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...OneTimePurchase.availablePurchases.map((purchase) {
          final isPurchased =
              _isPurchaseAlreadyOwned(purchase, purchaseService);
          return _buildPurchaseCard(purchase, isPurchased, purchaseService);
        }),
      ],
    );
  }

  /// 購入済みかどうかをチェック
  bool _isPurchaseAlreadyOwned(
      OneTimePurchase purchase, OneTimePurchaseService service) {
    return service.isPremiumUnlocked;
  }

  /// 購入カード
  Widget _buildPurchaseCard(OneTimePurchase purchase, bool isPurchased,
      OneTimePurchaseService service) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        purchase.name,
                        style: TextStyle(
                          fontSize: theme.textTheme.headlineMedium?.fontSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        purchase.description,
                        style: TextStyle(
                          fontSize: theme.textTheme.bodyMedium?.fontSize,
                          color: theme.subtextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '¥${purchase.price}',
                      style: TextStyle(
                        fontSize: theme.textTheme.headlineLarge?.fontSize,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: colorScheme.tertiary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '全機能パック',
                        style: TextStyle(
                          color: colorScheme.onTertiary,
                          fontSize: theme.textTheme.bodySmall?.fontSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 機能一覧
            ...purchase.features.map((feature) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        feature,
                        style: TextStyle(
                            fontSize: theme.textTheme.bodyMedium?.fontSize),
                      ),
                    ],
                  ),
                )),

            const SizedBox(height: 16),

            // 購入ボタン
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isPurchased || _isLoading
                    ? null
                    : () => _purchaseProduct(purchase, service),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  isPurchased ? '購入済み' : '購入する',
                  style: TextStyle(
                    fontSize: theme.textTheme.bodyLarge?.fontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// エラーセクション
  Widget _buildErrorSection(String error) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      color: colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.error,
              color: colorScheme.error,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                error,
                style: TextStyle(
                  color: colorScheme.onErrorContainer,
                  fontSize: theme.textTheme.bodyMedium?.fontSize,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 商品を購入
  Future<void> _purchaseProduct(
      OneTimePurchase purchase, OneTimePurchaseService service) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final success = await service.purchaseProduct(purchase);
      if (success) {
        if (mounted) {
          showSuccessSnackBar(context, '${purchase.name}の購入を開始しました');
        }
      } else {
        if (mounted) {
          showErrorSnackBar(context, '購入に失敗しました: ${service.error ?? '不明なエラー'}');
        }
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, '購入エラー: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
