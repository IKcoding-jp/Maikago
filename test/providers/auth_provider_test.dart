import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:maikago/providers/auth_provider.dart';
import 'package:maikago/models/migration_result.dart';
import 'package:maikago/services/one_time_purchase_service.dart';
import 'package:maikago/services/feature_access_control.dart';

/// テスト用のFake OneTimePurchaseService
class FakeOneTimePurchaseService extends ChangeNotifier
    implements OneTimePurchaseService {
  bool _isPremiumUnlocked = false;

  void setPremiumUnlocked(bool value) {
    _isPremiumUnlocked = value;
    notifyListeners();
  }

  @override
  bool get isPremiumUnlocked => _isPremiumUnlocked;
  @override
  bool get isPremiumPurchased => _isPremiumUnlocked;
  @override
  bool get isTrialActive => false;
  @override
  Duration? get trialRemainingDuration => null;
  @override
  bool get isStoreAvailable => true;
  @override
  String? get error => null;
  @override
  bool get isLoading => false;
  @override
  bool get isInitialized => true;
  @override
  Future<void> get initialized => Future.value();
  @override
  DateTime? get trialStartDate => null;
  @override
  DateTime? get trialEndDate => null;
  @override
  bool get isTrialEverStarted => false;
  @override
  bool get isDebugPremiumOverrideActive => false;

  String? lastInitializedUserId;
  bool resetForLogoutCalled = false;

  @override
  Future<void> initialize({String? userId}) async {
    lastInitializedUserId = userId;
  }

  @override
  Future<bool> purchaseProduct(product) async => false;
  @override
  Future<bool> restorePurchases() async => false;
  @override
  void startTrial(int trialDays) {}
  @override
  void endTrial() {}
  @override
  void clearError() {}
  @override
  void debugSetPremiumOverride(bool? value) {}

  @override
  void resetForLogout() {
    resetForLogoutCalled = true;
  }

  // テストシーム（本体の @visibleForTesting メソッド）。このFakeでは未使用。
  @override
  void setCurrentUserIdForTest(String userId) {}
  @override
  Future<void> handleSuccessfulPurchaseForTest(PurchaseDetails details) async {}
  @override
  set deviceFingerprintForTest(String value) {}
  @override
  Future<void> loadFromFirestoreForTest() async {}
  @override
  bool get needsServerReverificationForTest => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AuthProvider authProvider;
  late FakeOneTimePurchaseService fakePurchaseService;
  late FeatureAccessControl featureControl;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    fakePurchaseService = FakeOneTimePurchaseService();
    featureControl = FeatureAccessControl();
    // FeatureAccessControlを初期化（disposeでLateInitializationErrorを防ぐ）
    await featureControl.initialize(fakePurchaseService);

    authProvider = AuthProvider(
      purchaseService: fakePurchaseService,
      featureControl: featureControl,
    );

    // AuthProviderのコンストラクタが非同期初期化を開始するので待機
    // Firebase未初期化環境ではローカルモードで初期化される
    await Future.delayed(const Duration(milliseconds: 100));
  });

  tearDown(() {
    authProvider.dispose();
    featureControl.dispose();
    fakePurchaseService.dispose();
  });

  group('初期状態（Firebase未初期化時のローカルモード）', () {
    test('isLoggedInがfalse', () {
      expect(authProvider.isLoggedIn, false);
    });

    test('userがnull', () {
      expect(authProvider.user, isNull);
    });

    test('isGuestModeがfalse', () {
      expect(authProvider.isGuestMode, false);
    });

    test('canUseAppがfalse（ログインもゲストモードもなし）', () {
      expect(authProvider.canUseApp, false);
    });

    test('初期化完了後にisLoadingがfalse', () {
      expect(authProvider.isLoading, false);
    });
  });

  group('ゲストモード', () {
    test('enterGuestModeでゲストモードに入れる', () {
      authProvider.enterGuestMode();

      expect(authProvider.isGuestMode, true);
      expect(authProvider.canUseApp, true);
    });

    test('enterGuestModeでnotifyListenersが呼ばれる', () {
      var notified = false;
      authProvider.addListener(() => notified = true);

      authProvider.enterGuestMode();

      expect(notified, true);
    });

    test('ゲストモードでもisLoggedInはfalse', () {
      authProvider.enterGuestMode();

      expect(authProvider.isLoggedIn, false);
    });

    test('ゲストモードフラグがSharedPreferencesに保存される', () async {
      authProvider.enterGuestMode();

      // 非同期保存を待つ
      await Future.delayed(const Duration(milliseconds: 50));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('is_guest_mode'), true);
    });
  });

  group('ゲストモード復元', () {
    test('SharedPreferencesからゲストモードを復元', () async {
      // ゲストモードが保存された状態でAuthProviderを再作成
      SharedPreferences.setMockInitialValues({'is_guest_mode': true});

      final newFakePurchase = FakeOneTimePurchaseService();
      final newFeatureControl = FeatureAccessControl();
      await newFeatureControl.initialize(newFakePurchase);
      final newProvider = AuthProvider(
        purchaseService: newFakePurchase,
        featureControl: newFeatureControl,
      );

      await Future.delayed(const Duration(milliseconds: 100));

      expect(newProvider.isGuestMode, true);
      expect(newProvider.canUseApp, true);

      newProvider.dispose();
      newFeatureControl.dispose();
      newFakePurchase.dispose();
    });
  });

  group('ゲストデータマイグレーションコールバック', () {
    test('コールバックを設定できる', () {
      var called = false;
      authProvider.setGuestDataMigrationCallback(() async {
        called = true;
        return MigrationResult.empty;
      });

      // コールバックが設定されたことの間接確認
      // （signInWithGoogleを呼ばない限り実行されない）
      expect(called, false);
    });
  });

  group('ユーザー情報', () {
    test('未ログイン時のuserDisplayNameがnull', () {
      expect(authProvider.userDisplayName, isNull);
    });

    test('未ログイン時のuserEmailがnull', () {
      expect(authProvider.userEmail, isNull);
    });

    test('未ログイン時のuserPhotoURLがnull', () {
      expect(authProvider.userPhotoURL, isNull);
    });

    test('未ログイン時のuserIdが空文字', () {
      expect(authProvider.userId, '');
    });
  });

  group('dispose', () {
    test('dispose後にエラーが出ない', () async {
      // 新しいインスタンスを作成してdisposeテスト
      final newFakePurchase = FakeOneTimePurchaseService();
      final newFeatureControl = FeatureAccessControl();
      await newFeatureControl.initialize(newFakePurchase);
      final newProvider = AuthProvider(
        purchaseService: newFakePurchase,
        featureControl: newFeatureControl,
      );

      await Future.delayed(const Duration(milliseconds: 100));

      // dispose後にエラーが出ないことを確認
      newProvider.dispose();
      newFeatureControl.dispose();
      newFakePurchase.dispose();
    });
  });
}
