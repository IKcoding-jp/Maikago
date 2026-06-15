import 'package:flutter/material.dart';
import 'package:maikago/models/one_time_purchase.dart';
import 'package:maikago/services/one_time_purchase_service.dart';
import 'package:maikago/utils/snackbar_utils.dart';
import 'package:maikago/utils/theme_utils.dart';

/// プレミアム画面の購入セクション
class PremiumPurchaseSection extends StatefulWidget {
  const PremiumPurchaseSection({
    super.key,
    required this.purchaseService,
  });

  final OneTimePurchaseService purchaseService;

  @override
  State<PremiumPurchaseSection> createState() => _PremiumPurchaseSectionState();
}

class _PremiumPurchaseSectionState extends State<PremiumPurchaseSection> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        children: [
          if (widget.purchaseService.isPremiumUnlocked) ...[
            // 購入済みの場合
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 48,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'プレミアム機能を利用中',
                    style: TextStyle(
                      fontSize:
                          Theme.of(context).textTheme.headlineLarge?.fontSize,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'すべての機能が利用可能です',
                    style: TextStyle(
                      fontSize: Theme.of(context).textTheme.bodyLarge?.fontSize,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // 未購入の場合
            _buildPurchaseCard(
                OneTimePurchase.premium, false, widget.purchaseService),
          ],
        ],
      ),
    );
  }

  /// 購入カード
  Widget _buildPurchaseCard(OneTimePurchase purchase, bool isPurchased,
      OneTimePurchaseService service) {
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
                          fontSize: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.fontSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        purchase.description,
                        style: TextStyle(
                          fontSize:
                              Theme.of(context).textTheme.bodyMedium?.fontSize,
                          color: Theme.of(context).subtextColor,
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
                        fontSize:
                            Theme.of(context).textTheme.headlineLarge?.fontSize,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.tertiary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '全機能パック',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontSize:
                              Theme.of(context).textTheme.bodySmall?.fontSize,
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
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        feature,
                        style: TextStyle(
                            fontSize: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.fontSize),
                      ),
                    ],
                  ),
                )),

            const SizedBox(height: 16),

            // 購入ボタン
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isPurchased || _isLoading
                        ? null
                        : () => _purchaseProduct(purchase, service),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      isPurchased ? '購入済み' : '購入する',
                      style: TextStyle(
                        fontSize:
                            Theme.of(context).textTheme.bodyLarge?.fontSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
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
