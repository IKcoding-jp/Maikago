import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:maikago/services/purchase/purchase_validator.dart';

/// テスト用に PurchaseDetails を組み立てるヘルパー
PurchaseDetails _buildDetails({
  String productID = 'maikago_premium_unlock',
  String serverVerificationData = 'valid_purchase_token',
  PurchaseStatus status = PurchaseStatus.purchased,
}) {
  return PurchaseDetails(
    productID: productID,
    verificationData: PurchaseVerificationData(
      localVerificationData: 'local',
      serverVerificationData: serverVerificationData,
      source: 'google_play',
    ),
    transactionDate: '0',
    status: status,
  );
}

void main() {
  group('PurchaseValidator.isValidPremiumPurchase', () {
    test('正規の購入（purchased・正しいID・検証データあり）はtrue', () {
      final details = _buildDetails();

      expect(PurchaseValidator.isValidPremiumPurchase(details), true);
    });

    test('復元（restored）も正規ならtrue', () {
      final details = _buildDetails(status: PurchaseStatus.restored);

      expect(PurchaseValidator.isValidPremiumPurchase(details), true);
    });

    test('検証データ（serverVerificationData）が空ならfalse', () {
      final details = _buildDetails(serverVerificationData: '');

      expect(PurchaseValidator.isValidPremiumPurchase(details), false);
    });

    test('商品IDが想定外ならfalse', () {
      final details = _buildDetails(productID: 'some_other_product');

      expect(PurchaseValidator.isValidPremiumPurchase(details), false);
    });

    test('statusがpendingならfalse', () {
      final details = _buildDetails(status: PurchaseStatus.pending);

      expect(PurchaseValidator.isValidPremiumPurchase(details), false);
    });

    test('statusがerrorならfalse', () {
      final details = _buildDetails(status: PurchaseStatus.error);

      expect(PurchaseValidator.isValidPremiumPurchase(details), false);
    });

    test('statusがcanceledならfalse', () {
      final details = _buildDetails(status: PurchaseStatus.canceled);

      expect(PurchaseValidator.isValidPremiumPurchase(details), false);
    });

    test('検証データが空白のみ（空白文字）ならfalse', () {
      final details = _buildDetails(serverVerificationData: '   ');

      expect(PurchaseValidator.isValidPremiumPurchase(details), false);
    });
  });
}
