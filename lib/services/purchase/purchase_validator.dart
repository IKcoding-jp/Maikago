import 'package:in_app_purchase/in_app_purchase.dart';

/// 課金の購入情報（[PurchaseDetails]）がプレミアム有効化に値するかを
/// 検証する純粋ロジック。
///
/// 注意: これは「クライアント側の一次防御」であり、署名（レシート）の
/// 暗号学的検証ではない。改竄に対する真の防御はサーバー（Cloud Functions
/// での Google Play / App Store レシート検証）で行う必要がある（Issue #163 の
/// 対応案#1。本バリデータとは別Issueで対応）。
class PurchaseValidator {
  PurchaseValidator._();

  /// プレミアム有効化に対応する商品ID。
  static const Set<String> premiumProductIds = {
    'maikago_premium_unlock',
  };

  /// [details] がプレミアムを有効化してよい正規の購入情報かどうかを返す。
  ///
  /// 次のすべてを満たす場合のみ true:
  /// - status が purchased または restored
  /// - productID が [premiumProductIds] に含まれる
  /// - serverVerificationData が空でない（空白のみも不可）
  static bool isValidPremiumPurchase(PurchaseDetails details) {
    final isCompleted = details.status == PurchaseStatus.purchased ||
        details.status == PurchaseStatus.restored;
    if (!isCompleted) return false;

    if (!premiumProductIds.contains(details.productID)) return false;

    final verification = details.verificationData.serverVerificationData;
    if (verification.trim().isEmpty) return false;

    return true;
  }
}
