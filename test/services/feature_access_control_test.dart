import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:maikago/services/feature_access_control.dart';
import 'package:maikago/services/one_time_purchase_service.dart';

/// テスト用のFake OneTimePurchaseService
///
/// OneTimePurchaseServiceはFirebase/InAppPurchaseに強く依存するため、
/// Mockitoではなく手動Fakeを使用する。
class FakeOneTimePurchaseService extends ChangeNotifier
    implements OneTimePurchaseService {
  bool _isPremiumUnlocked = false;
  bool _isTrialActive = false;
  Duration? _trialRemainingDuration;
  final bool _isStoreAvailable = true;
  final String? _error = null;
  final bool _isLoading = false;

  void setPremiumUnlocked(bool value) {
    _isPremiumUnlocked = value;
    notifyListeners();
  }

  bool? _debugPremiumOverrideValue;

  @override
  void debugSetPremiumOverride(bool? value) {
    _debugPremiumOverrideValue = value;
    notifyListeners();
  }

  @override
  bool get isDebugPremiumOverrideActive => _debugPremiumOverrideValue != null;

  void setTrialActive(bool value) {
    _isTrialActive = value;
    notifyListeners();
  }

  @override
  bool get isPremiumUnlocked => _isPremiumUnlocked;

  @override
  bool get isPremiumPurchased => _isPremiumUnlocked;

  @override
  bool get isTrialActive => _isTrialActive;

  @override
  Duration? get trialRemainingDuration => _trialRemainingDuration;

  @override
  bool get isStoreAvailable => _isStoreAvailable;

  @override
  String? get error => _error;

  @override
  bool get isLoading => _isLoading;

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

  // 未使用のメソッドは空実装
  @override
  Future<void> initialize({String? userId}) async {}

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
  void resetForLogout() {}

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
  late FeatureAccessControl featureAccessControl;
  late FakeOneTimePurchaseService fakePurchaseService;

  setUp(() async {
    // SharedPreferencesのモック初期化
    SharedPreferences.setMockInitialValues({});

    fakePurchaseService = FakeOneTimePurchaseService();
    featureAccessControl = FeatureAccessControl();
    await featureAccessControl.initialize(fakePurchaseService);
  });

  tearDown(() {
    featureAccessControl.dispose();
    fakePurchaseService.dispose();
  });

  group('初期化', () {
    test('initialize()でOneTimePurchaseServiceのリスナーが登録される', () {
      // fakePurchaseServiceの変更がfeatureAccessControlに伝播することを確認
      var notified = false;
      featureAccessControl.addListener(() => notified = true);

      fakePurchaseService.setPremiumUnlocked(true);

      expect(notified, true);
    });

    test('dispose()後はリスナーが解除される', () async {
      // 新しいインスタンスを作成してdispose
      final fac = FeatureAccessControl();
      final fps = FakeOneTimePurchaseService();
      await fac.initialize(fps);
      fac.dispose();

      // dispose後の変更通知でエラーが出ないことを確認
      // （リスナーが解除されていれば問題なし）
      fps.setPremiumUnlocked(true);
      fps.dispose();
    });
  });

  group('プレミアム判定', () {
    test('プレミアム時にisPremiumUnlocked=true', () {
      fakePurchaseService.setPremiumUnlocked(true);

      expect(featureAccessControl.isPremiumUnlocked, true);
    });

    test('非プレミアム時にisPremiumUnlocked=false', () {
      expect(featureAccessControl.isPremiumUnlocked, false);
    });
  });

  group('canCustomizeTheme', () {
    test('プレミアム時にtrue', () {
      fakePurchaseService.setPremiumUnlocked(true);

      expect(featureAccessControl.canCustomizeTheme(), true);
    });

    test('非プレミアム時にfalse', () {
      expect(featureAccessControl.canCustomizeTheme(), false);
    });
  });

  group('canCustomizeFont', () {
    test('プレミアム時にtrue', () {
      fakePurchaseService.setPremiumUnlocked(true);

      expect(featureAccessControl.canCustomizeFont(), true);
    });

    test('非プレミアム時にfalse', () {
      expect(featureAccessControl.canCustomizeFont(), false);
    });
  });

  group('shouldShowAds', () {
    test('プレミアム時にfalse（広告非表示）', () {
      fakePurchaseService.setPremiumUnlocked(true);

      expect(featureAccessControl.shouldShowAds(), false);
    });

    test('非プレミアム時にtrue（広告表示）', () {
      expect(featureAccessControl.shouldShowAds(), true);
    });
  });

  group('isFeatureAvailable', () {
    test('プレミアム時にthemeCustomizationが利用可能', () {
      fakePurchaseService.setPremiumUnlocked(true);

      expect(
        featureAccessControl.isFeatureAvailable(FeatureType.themeCustomization),
        true,
      );
    });

    test('プレミアム時にfontCustomizationが利用可能', () {
      fakePurchaseService.setPremiumUnlocked(true);

      expect(
        featureAccessControl.isFeatureAvailable(FeatureType.fontCustomization),
        true,
      );
    });

    test('プレミアム時にadRemovalが利用可能', () {
      fakePurchaseService.setPremiumUnlocked(true);

      expect(
        featureAccessControl.isFeatureAvailable(FeatureType.adRemoval),
        true,
      );
    });

    test('プレミアム時にすべての機能が利用可能', () {
      fakePurchaseService.setPremiumUnlocked(true);

      for (final featureType in FeatureType.values) {
        expect(
          featureAccessControl.isFeatureAvailable(featureType),
          true,
          reason: '${featureType.name} should be available for premium users',
        );
      }
    });

    test('非プレミアム時にプレミアム限定機能が利用不可', () {
      // プレミアム限定（常にロック）の機能
      expect(
        featureAccessControl.isFeatureAvailable(FeatureType.themeCustomization),
        false,
      );
      expect(
        featureAccessControl.isFeatureAvailable(FeatureType.fontCustomization),
        false,
      );
      expect(
        featureAccessControl.isFeatureAvailable(FeatureType.adRemoval),
        false,
      );
      expect(
        featureAccessControl.isFeatureAvailable(FeatureType.shopUnlimited),
        false,
      );
      expect(
        featureAccessControl.isFeatureAvailable(FeatureType.recipeParser),
        false,
      );
    });

    test('非プレミアム時にOCRは5回まで利用可能', () {
      // OCRは無料ユーザーでも5回まで使えるのでtrue
      expect(
        featureAccessControl.isFeatureAvailable(FeatureType.ocrUnlimited),
        true,
      );
    });
  });

  group('isFeatureLocked', () {
    test('非プレミアム時にプレミアム限定機能がロック', () {
      expect(
        featureAccessControl.isFeatureLocked(FeatureType.themeCustomization),
        true,
      );
      expect(
        featureAccessControl.isFeatureLocked(FeatureType.fontCustomization),
        true,
      );
      expect(
        featureAccessControl.isFeatureLocked(FeatureType.adRemoval),
        true,
      );
      expect(
        featureAccessControl.isFeatureLocked(FeatureType.shopUnlimited),
        true,
      );
      expect(
        featureAccessControl.isFeatureLocked(FeatureType.recipeParser),
        true,
      );
    });

    test('プレミアム時にすべての機能がアンロック', () {
      fakePurchaseService.setPremiumUnlocked(true);

      for (final featureType in FeatureType.values) {
        expect(
          featureAccessControl.isFeatureLocked(featureType),
          false,
        );
      }
    });
  });

  group('hasReachedLimit', () {
    test('非プレミアム時にthemeLimitに達している', () {
      expect(
        featureAccessControl.hasReachedLimit(LimitReachedType.themeLimit),
        true,
      );
    });

    test('非プレミアム時にfontLimitに達している', () {
      expect(
        featureAccessControl.hasReachedLimit(LimitReachedType.fontLimit),
        true,
      );
    });

    test('featureLockedは常にfalse', () {
      expect(
        featureAccessControl.hasReachedLimit(LimitReachedType.featureLocked),
        false,
      );
    });

    test('プレミアム時にはthemeLimit/fontLimitに達していない', () {
      fakePurchaseService.setPremiumUnlocked(true);

      expect(
        featureAccessControl.hasReachedLimit(LimitReachedType.themeLimit),
        false,
      );
      expect(
        featureAccessControl.hasReachedLimit(LimitReachedType.fontLimit),
        false,
      );
    });
  });

  group('getRecommendedUpgradePlan', () {
    test('プレミアム時はisAlreadyOwned=true', () {
      fakePurchaseService.setPremiumUnlocked(true);

      final plan = featureAccessControl.getRecommendedUpgradePlan();

      expect(plan['isAlreadyOwned'], true);
      expect(plan['type'], 'premium');
      expect(plan['price'], 500);
    });

    test('非プレミアム時はisAlreadyOwned=false', () {
      final plan = featureAccessControl.getRecommendedUpgradePlan();

      expect(plan['isAlreadyOwned'], false);
      expect(plan['type'], 'premium');
      expect(plan['price'], 500);
      expect(plan['features'], isA<List>());
    });

    test('非プレミアム時のfeatures一覧に新機能が含まれる', () {
      final plan = featureAccessControl.getRecommendedUpgradePlan();
      final features = plan['features'] as List;

      expect(features, contains('OCR（値札撮影）無制限'));
      expect(features, contains('ショップ（タブ）無制限'));
      expect(features, contains('レシピ解析'));
    });
  });

  group('getFeatureDescription', () {
    test('各FeatureTypeの説明が取得できる', () {
      expect(
        featureAccessControl
            .getFeatureDescription(FeatureType.themeCustomization),
        'テーマカスタマイズ',
      );
      expect(
        featureAccessControl
            .getFeatureDescription(FeatureType.fontCustomization),
        'フォントカスタマイズ',
      );
      expect(
        featureAccessControl.getFeatureDescription(FeatureType.adRemoval),
        '広告非表示',
      );
      expect(
        featureAccessControl.getFeatureDescription(FeatureType.ocrUnlimited),
        'OCR無制限',
      );
      expect(
        featureAccessControl.getFeatureDescription(FeatureType.shopUnlimited),
        'ショップ無制限',
      );
      expect(
        featureAccessControl.getFeatureDescription(FeatureType.recipeParser),
        'レシピ解析',
      );
    });
  });

  group('getLimitDescription', () {
    test('各LimitReachedTypeの説明が取得できる', () {
      expect(
        featureAccessControl.getLimitDescription(LimitReachedType.themeLimit),
        'テーマ制限',
      );
      expect(
        featureAccessControl.getLimitDescription(LimitReachedType.fontLimit),
        'フォント制限',
      );
      expect(
        featureAccessControl
            .getLimitDescription(LimitReachedType.featureLocked),
        '機能ロック',
      );
    });
  });

  group('getUsageStats', () {
    test('非プレミアム時の使用状況統計', () {
      final stats = featureAccessControl.getUsageStats();

      expect(stats['currentPlan'], isA<Map>());
      expect(stats['features'], isA<Map>());
      expect(stats['recommendedUpgrade'], isA<Map>());

      final features = stats['features'] as Map<String, dynamic>;
      final theme = features['themeCustomization'] as Map<String, dynamic>;
      final font = features['fontCustomization'] as Map<String, dynamic>;
      final ad = features['adRemoval'] as Map<String, dynamic>;
      expect(theme['available'], false);
      expect(font['available'], false);
      expect(ad['available'], false);
    });

    test('プレミアム時の使用状況統計', () {
      fakePurchaseService.setPremiumUnlocked(true);

      final stats = featureAccessControl.getUsageStats();
      final features = stats['features'] as Map<String, dynamic>;
      final theme = features['themeCustomization'] as Map<String, dynamic>;
      final font = features['fontCustomization'] as Map<String, dynamic>;
      final ad = features['adRemoval'] as Map<String, dynamic>;

      expect(theme['available'], true);
      expect(font['available'], true);
      expect(ad['available'], true);
    });
  });

  group('currentPlanInfo', () {
    test('プラン情報にisPremiumが含まれる', () {
      final info = featureAccessControl.currentPlanInfo;

      expect(info['isPremium'], false);
      expect(info['isTrialActive'], false);
    });

    test('プレミアム時のプラン情報', () {
      fakePurchaseService.setPremiumUnlocked(true);

      final info = featureAccessControl.currentPlanInfo;

      expect(info['isPremium'], true);
    });
  });

  // ===== 新機能制限のテスト =====

  group('OCR月間使用制限', () {
    test('無料ユーザーは月5回までOCR利用可能', () {
      expect(featureAccessControl.canUseOcr(), true);
      expect(featureAccessControl.ocrRemainingCount, 5);
    });

    test('無料ユーザーが5回使うとOCR利用不可になる', () {
      for (var i = 0; i < 5; i++) {
        expect(featureAccessControl.canUseOcr(), true);
        featureAccessControl.incrementOcrUsage();
      }

      expect(featureAccessControl.canUseOcr(), false);
      expect(featureAccessControl.ocrRemainingCount, 0);
    });

    test('無料ユーザーの残り回数が正しく減少する', () {
      expect(featureAccessControl.ocrRemainingCount, 5);

      featureAccessControl.incrementOcrUsage();
      expect(featureAccessControl.ocrRemainingCount, 4);

      featureAccessControl.incrementOcrUsage();
      expect(featureAccessControl.ocrRemainingCount, 3);

      featureAccessControl.incrementOcrUsage();
      expect(featureAccessControl.ocrRemainingCount, 2);

      featureAccessControl.incrementOcrUsage();
      expect(featureAccessControl.ocrRemainingCount, 1);

      featureAccessControl.incrementOcrUsage();
      expect(featureAccessControl.ocrRemainingCount, 0);
    });

    test('プレミアムユーザーはOCR無制限', () {
      fakePurchaseService.setPremiumUnlocked(true);

      expect(featureAccessControl.canUseOcr(), true);
      expect(featureAccessControl.ocrRemainingCount, 999);
    });

    test('プレミアムユーザーはincrementOcrUsageでカウントが増えない', () {
      fakePurchaseService.setPremiumUnlocked(true);

      featureAccessControl.incrementOcrUsage();
      featureAccessControl.incrementOcrUsage();
      featureAccessControl.incrementOcrUsage();

      expect(featureAccessControl.ocrRemainingCount, 999);
    });

    test('resetMonthlyOcrCountでカウントがリセットされる', () {
      // 3回使用
      featureAccessControl.incrementOcrUsage();
      featureAccessControl.incrementOcrUsage();
      featureAccessControl.incrementOcrUsage();
      expect(featureAccessControl.ocrRemainingCount, 2);

      // リセット
      featureAccessControl.resetMonthlyOcrCount();
      expect(featureAccessControl.ocrRemainingCount, 5);
      expect(featureAccessControl.canUseOcr(), true);
    });

    test('incrementOcrUsage時にnotifyListenersが呼ばれる', () {
      var notified = false;
      featureAccessControl.addListener(() => notified = true);

      featureAccessControl.incrementOcrUsage();

      expect(notified, true);
    });

    test('resetMonthlyOcrCount時にnotifyListenersが呼ばれる', () {
      var notified = false;
      featureAccessControl.addListener(() => notified = true);

      featureAccessControl.resetMonthlyOcrCount();

      expect(notified, true);
    });

    test('OCR使用状況がSharedPreferencesに保存される', () async {
      featureAccessControl.incrementOcrUsage();
      featureAccessControl.incrementOcrUsage();

      // SharedPreferencesの非同期保存を待つ
      await Future.delayed(Duration.zero);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('ocr_monthly_usage_count'), 2);
      expect(prefs.getString('ocr_count_month'), isNotEmpty);
    });

    test('初期化時にSharedPreferencesからOCR使用状況が復元される', () async {
      // 事前にSharedPreferencesにデータをセット
      final now = DateTime.now();
      final currentMonth =
          '${now.year}-${now.month.toString().padLeft(2, '0')}';
      SharedPreferences.setMockInitialValues({
        'ocr_monthly_usage_count': 3,
        'ocr_count_month': currentMonth,
      });

      // 新しいインスタンスで初期化
      final fac = FeatureAccessControl();
      final fps = FakeOneTimePurchaseService();
      await fac.initialize(fps);

      expect(fac.ocrRemainingCount, 2); // 5 - 3 = 2
      expect(fac.canUseOcr(), true);

      fac.dispose();
      fps.dispose();
    });

    test('月が変わるとカウントがリセットされる', () async {
      // 先月のデータをセット
      SharedPreferences.setMockInitialValues({
        'ocr_monthly_usage_count': 5,
        'ocr_count_month': '2020-01', // 過去の月
      });

      final fac = FeatureAccessControl();
      final fps = FakeOneTimePurchaseService();
      await fac.initialize(fps);

      // 月が変わっているのでリセットされる
      expect(fac.ocrRemainingCount, 5);
      expect(fac.canUseOcr(), true);

      fac.dispose();
      fps.dispose();
    });

    test('maxFreeOcrPerMonthの定数が5である', () {
      expect(FeatureAccessControl.maxFreeOcrPerMonth, 5);
    });
  });

  group('ショップ数制限', () {
    test('無料ユーザーはショップ2つまで作成可能', () {
      expect(featureAccessControl.canCreateShop(currentShopCount: 0), true);
      expect(featureAccessControl.canCreateShop(currentShopCount: 1), true);
    });

    test('無料ユーザーはショップ2つ以上作成不可', () {
      expect(featureAccessControl.canCreateShop(currentShopCount: 2), false);
      expect(featureAccessControl.canCreateShop(currentShopCount: 3), false);
      expect(featureAccessControl.canCreateShop(currentShopCount: 10), false);
    });

    test('プレミアムユーザーはショップ無制限', () {
      fakePurchaseService.setPremiumUnlocked(true);

      expect(featureAccessControl.canCreateShop(currentShopCount: 0), true);
      expect(featureAccessControl.canCreateShop(currentShopCount: 2), true);
      expect(featureAccessControl.canCreateShop(currentShopCount: 10), true);
      expect(featureAccessControl.canCreateShop(currentShopCount: 100), true);
    });

    test('maxFreeShopsの定数が2である', () {
      expect(FeatureAccessControl.maxFreeShops, 2);
    });
  });

  group('レシピ解析（プレミアム限定）', () {
    test('無料ユーザーはレシピ解析を利用不可', () {
      expect(featureAccessControl.canUseRecipeParser(), false);
    });

    test('プレミアムユーザーはレシピ解析を利用可能', () {
      fakePurchaseService.setPremiumUnlocked(true);

      expect(featureAccessControl.canUseRecipeParser(), true);
    });

    test('isFeatureAvailableでrecipeParserのチェックが正しい', () {
      expect(
        featureAccessControl.isFeatureAvailable(FeatureType.recipeParser),
        false,
      );

      fakePurchaseService.setPremiumUnlocked(true);
      expect(
        featureAccessControl.isFeatureAvailable(FeatureType.recipeParser),
        true,
      );
    });
  });
}
