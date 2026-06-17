import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:maikago/services/one_time_purchase_service.dart';
import 'package:maikago/services/purchase/purchase_persistence.dart';
import 'package:maikago/services/purchase/purchase_verifier.dart';

/// 設定可能なFake検証器。
class FakePurchaseVerifier implements PurchaseVerifier {
  FakePurchaseVerifier({
    this.result = const PurchaseVerificationResult(verified: true),
    this.throwError,
  });

  PurchaseVerificationResult result;
  PurchaseVerificationException? throwError;

  int callCount = 0;
  String? lastPlatform;
  String? lastProductId;
  String? lastPurchaseToken;

  @override
  Future<PurchaseVerificationResult> verify({
    required String platform,
    required String productId,
    required String purchaseToken,
  }) async {
    callCount++;
    lastPlatform = platform;
    lastProductId = productId;
    lastPurchaseToken = purchaseToken;
    if (throwError != null) throw throwError!;
    return result;
  }
}

/// Firestore/SharedPreferences に触れないFake永続化。
class FakePurchasePersistence extends PurchasePersistence {
  @override
  Future<void> saveToLocalStorage({
    required Map<String, bool> userPremiumStatus,
    required bool isTrialActive,
    required bool isTrialEverStarted,
    DateTime? trialStartDate,
    DateTime? trialEndDate,
  }) async {}

  @override
  Future<void> saveToFirestore({
    required String userId,
    required String deviceFingerprint,
    required bool isPremium,
    required bool isTrialEverStarted,
    DateTime? trialStartDate,
    DateTime? trialEndDate,
  }) async {}
}

PurchaseDetails _premiumPurchase({
  PurchaseStatus status = PurchaseStatus.purchased,
  String productID = 'maikago_premium_unlock',
  String serverVerificationData = 'token-abc',
}) {
  return PurchaseDetails(
    purchaseID: 'p1',
    productID: productID,
    verificationData: PurchaseVerificationData(
      localVerificationData: 'local',
      serverVerificationData: serverVerificationData,
      source: 'google_play',
    ),
    transactionDate: null,
    status: status,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  group('Android: サーバー検証を通したときのみプレミアム付与（Issue #163）', () {
    test('サーバー検証成功 → プレミアム付与・検証器に正しい引数を渡す', () async {
      final verifier = FakePurchaseVerifier(
        result: const PurchaseVerificationResult(verified: true),
      );
      final service = OneTimePurchaseService(
        purchaseVerifier: verifier,
        persistence: FakePurchasePersistence(),
      );
      service.setCurrentUserIdForTest('user1');

      await service.handleSuccessfulPurchaseForTest(_premiumPurchase());

      expect(service.isPremiumPurchased, true);
      expect(verifier.callCount, 1);
      expect(verifier.lastPlatform, 'android');
      expect(verifier.lastProductId, 'maikago_premium_unlock');
      expect(verifier.lastPurchaseToken, 'token-abc');

      service.dispose();
    });

    test('サーバー検証拒否（verified:false） → プレミアム付与しない', () async {
      final verifier = FakePurchaseVerifier(
        result: const PurchaseVerificationResult(verified: false),
      );
      final service = OneTimePurchaseService(
        purchaseVerifier: verifier,
        persistence: FakePurchasePersistence(),
      );
      service.setCurrentUserIdForTest('user1');

      await service.handleSuccessfulPurchaseForTest(_premiumPurchase());

      expect(service.isPremiumPurchased, false);
      expect(verifier.callCount, 1);

      service.dispose();
    });

    test('サーバー検証が例外 → プレミアム付与しない（改竄・通信失敗で得しない）', () async {
      final verifier = FakePurchaseVerifier(
        throwError: PurchaseVerificationException(
          'permission-denied',
          '購入を検証できませんでした',
        ),
      );
      final service = OneTimePurchaseService(
        purchaseVerifier: verifier,
        persistence: FakePurchasePersistence(),
      );
      service.setCurrentUserIdForTest('user1');

      await service.handleSuccessfulPurchaseForTest(_premiumPurchase());

      expect(service.isPremiumPurchased, false);

      service.dispose();
    });

    test('クライアント一次検証で不正（検証データ空） → 検証器を呼ばず付与しない', () async {
      final verifier = FakePurchaseVerifier();
      final service = OneTimePurchaseService(
        purchaseVerifier: verifier,
        persistence: FakePurchasePersistence(),
      );
      service.setCurrentUserIdForTest('user1');

      await service.handleSuccessfulPurchaseForTest(
        _premiumPurchase(serverVerificationData: '   '),
      );

      expect(service.isPremiumPurchased, false);
      expect(verifier.callCount, 0);

      service.dispose();
    });
  });

  group('iOS: サーバー検証は未実装のためクライアント一次検証のみで付与', () {
    test('iOS購入 → 検証器を呼ばずにクライアント検証のみで付与', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final verifier = FakePurchaseVerifier();
      final service = OneTimePurchaseService(
        purchaseVerifier: verifier,
        persistence: FakePurchasePersistence(),
      );
      service.setCurrentUserIdForTest('user1');

      await service.handleSuccessfulPurchaseForTest(
        _premiumPurchase(serverVerificationData: 'apple-receipt'),
      );

      expect(service.isPremiumPurchased, true);
      expect(verifier.callCount, 0); // iOSはサーバー検証を呼ばない（未実装）

      service.dispose();
    });
  });
}
