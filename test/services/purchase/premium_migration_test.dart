import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:maikago/services/one_time_purchase_service.dart';
import 'package:maikago/services/purchase/purchase_persistence.dart';
import 'package:maikago/services/purchase/purchase_verifier.dart';

class _NoopVerifier implements PurchaseVerifier {
  @override
  Future<PurchaseVerificationResult> verify({
    required String platform,
    required String productId,
    required String purchaseToken,
  }) async =>
      const PurchaseVerificationResult(verified: true);
}

/// サーバーエンタイトルメントとレガシーフラグを固定で返すFake永続化。
class FakeMigrationPersistence extends PurchasePersistence {
  FakeMigrationPersistence({
    required this.serverEntitlement,
    required this.legacyPremium,
  });

  final bool serverEntitlement;
  final bool legacyPremium;

  @override
  Future<bool> loadServerEntitlement({required String userId}) async =>
      serverEntitlement;

  @override
  Future<FirestorePurchaseData?> loadFromFirestore({
    required String userId,
    required String deviceFingerprint,
  }) async =>
      FirestorePurchaseData(
        isPremium: legacyPremium,
        isTrialEverStarted: false,
      );
}

OneTimePurchaseService _buildService(FakeMigrationPersistence persistence) {
  final service = OneTimePurchaseService(
    purchaseVerifier: _NoopVerifier(),
    persistence: persistence,
  );
  service.setCurrentUserIdForTest('user1');
  service.deviceFingerprintForTest = 'fp-1';
  return service;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  group('プレミアム読込元の一本化と移行（Issue #163 対応案#3）', () {
    test('Android: サーバー検証済みtrue → プレミアムtrue・再検証不要', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final service = _buildService(
        FakeMigrationPersistence(serverEntitlement: true, legacyPremium: false),
      );

      await service.loadFromFirestoreForTest();

      expect(service.isPremiumPurchased, true);
      expect(service.needsServerReverificationForTest, false);
      service.dispose();
    });

    test('Android: サーバー未検証・レガシーtrue → プレミアムfalse・再検証が必要', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final service = _buildService(
        FakeMigrationPersistence(serverEntitlement: false, legacyPremium: true),
      );

      await service.loadFromFirestoreForTest();

      // レガシーのクライアントフラグだけでは付与しない（改竄対策）
      expect(service.isPremiumPurchased, false);
      // 既存購入者をロックアウトしないため、自動再検証フラグを立てる
      expect(service.needsServerReverificationForTest, true);
      service.dispose();
    });

    test('Android: サーバー未検証・レガシーもfalse → プレミアムfalse・再検証不要', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final service = _buildService(
        FakeMigrationPersistence(
            serverEntitlement: false, legacyPremium: false),
      );

      await service.loadFromFirestoreForTest();

      expect(service.isPremiumPurchased, false);
      expect(service.needsServerReverificationForTest, false);
      service.dispose();
    });

    test('iOS: サーバー未検証・レガシーtrue → フォールバックでプレミアムtrue・再検証しない', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final service = _buildService(
        FakeMigrationPersistence(serverEntitlement: false, legacyPremium: true),
      );

      await service.loadFromFirestoreForTest();

      // iOSはサーバー検証未実装のため、既存挙動を壊さずレガシーフラグを尊重
      expect(service.isPremiumPurchased, true);
      expect(service.needsServerReverificationForTest, false);
      service.dispose();
    });
  });
}
