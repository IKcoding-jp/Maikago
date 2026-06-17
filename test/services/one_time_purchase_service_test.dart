import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:maikago/models/one_time_purchase.dart';
import 'package:maikago/services/one_time_purchase_service.dart';

/// テスト用のFake OneTimePurchaseService
///
/// OneTimePurchaseServiceの全パブリックAPIを実装し、
/// ビジネスロジックの期待動作を検証する。
///
/// InAppPurchase/Firebaseに依存する部分は個別テストでカバー:
/// - TrialManager: test/services/purchase/trial_manager_test.dart
/// - PurchasePersistence: test/services/purchase/purchase_persistence_test.dart
class FakeOneTimePurchaseService extends ChangeNotifier
    implements OneTimePurchaseService {
  // 購入状態
  final Map<String, bool> _userPremiumStatus = {};
  String _currentUserId = '';

  // 体験期間
  bool _isTrialActive = false;
  bool _isTrialEverStarted = false;
  DateTime? _trialStartDate;
  DateTime? _trialEndDate;

  // デバッグオーバーライド
  bool? _debugPremiumOverride;

  // サービス状態
  final bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;

  // テスト用制御メソッド
  void setPremiumStatus(String userId, bool isPremium) {
    _userPremiumStatus[userId] = isPremium;
    notifyListeners();
  }

  void setCurrentUserId(String userId) {
    _currentUserId = userId;
  }

  // === OneTimePurchaseService の実装 ===

  @override
  bool get isPremiumUnlocked =>
      _debugPremiumOverride ??
      ((_userPremiumStatus[_currentUserId] ?? false) || _isTrialActive);

  @override
  bool get isPremiumPurchased => _userPremiumStatus[_currentUserId] ?? false;

  @override
  bool get isTrialActive => _isTrialActive;

  @override
  bool get isTrialEverStarted => _isTrialEverStarted;

  @override
  DateTime? get trialStartDate => _trialStartDate;

  @override
  DateTime? get trialEndDate => _trialEndDate;

  @override
  Duration? get trialRemainingDuration {
    if (!_isTrialActive || _trialEndDate == null) return null;
    final remaining = _trialEndDate!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  @override
  bool get isLoading => _isLoading;

  @override
  String? get error => _error;

  @override
  bool get isStoreAvailable => false;

  @override
  bool get isInitialized => _isInitialized;

  @override
  Future<void> get initialized => Future.value();

  @override
  bool get isDebugPremiumOverrideActive => _debugPremiumOverride != null;

  @override
  void debugSetPremiumOverride(bool? value) {
    _debugPremiumOverride = value;
    notifyListeners();
  }

  @override
  Future<void> initialize({String? userId}) async {
    _currentUserId = userId ?? '';
    _isInitialized = true;
    notifyListeners();
  }

  @override
  void startTrial(int trialDays) {
    if (_isTrialEverStarted) return;
    _isTrialActive = true;
    _isTrialEverStarted = true;
    _trialStartDate = DateTime.now();
    _trialEndDate = _trialStartDate!.add(Duration(days: trialDays));
    notifyListeners();
  }

  @override
  void endTrial() {
    _isTrialActive = false;
    _trialStartDate = null;
    _trialEndDate = null;
    notifyListeners();
  }

  @override
  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void resetForLogout() {
    _currentUserId = '';
    notifyListeners();
  }

  @override
  Future<bool> purchaseProduct(product) async => false;

  @override
  Future<bool> restorePurchases() async => false;

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

  late FakeOneTimePurchaseService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = FakeOneTimePurchaseService();
  });

  tearDown(() {
    service.dispose();
  });

  group('初期状態', () {
    test('isPremiumUnlockedがfalse', () {
      expect(service.isPremiumUnlocked, false);
    });

    test('isPremiumPurchasedがfalse', () {
      expect(service.isPremiumPurchased, false);
    });

    test('isTrialActiveがfalse', () {
      expect(service.isTrialActive, false);
    });

    test('isTrialEverStartedがfalse', () {
      expect(service.isTrialEverStarted, false);
    });

    test('trialStartDateがnull', () {
      expect(service.trialStartDate, isNull);
    });

    test('trialEndDateがnull', () {
      expect(service.trialEndDate, isNull);
    });

    test('trialRemainingDurationがnull', () {
      expect(service.trialRemainingDuration, isNull);
    });

    test('isLoadingがfalse', () {
      expect(service.isLoading, false);
    });

    test('errorがnull', () {
      expect(service.error, isNull);
    });

    test('isInitializedがfalse', () {
      expect(service.isInitialized, false);
    });

    test('isDebugPremiumOverrideActiveがfalse', () {
      expect(service.isDebugPremiumOverrideActive, false);
    });
  });

  group('initialize', () {
    test('初期化完了でisInitializedがtrue', () async {
      await service.initialize(userId: 'user1');

      expect(service.isInitialized, true);
    });

    test('userIdを設定できる', () async {
      await service.initialize(userId: 'user1');
      service.setPremiumStatus('user1', true);

      expect(service.isPremiumUnlocked, true);
    });

    test('notifyListenersが呼ばれる', () async {
      var notified = false;
      service.addListener(() => notified = true);

      await service.initialize(userId: 'user1');

      expect(notified, true);
    });
  });

  group('isPremiumUnlockedのロジック', () {
    test('購入済みユーザーはtrue', () async {
      await service.initialize(userId: 'user1');
      service.setPremiumStatus('user1', true);

      expect(service.isPremiumUnlocked, true);
      expect(service.isPremiumPurchased, true);
    });

    test('未購入ユーザーはfalse', () async {
      await service.initialize(userId: 'user1');

      expect(service.isPremiumUnlocked, false);
      expect(service.isPremiumPurchased, false);
    });

    test('体験期間中はisPremiumUnlocked=true、isPremiumPurchased=false', () {
      service.startTrial(7);

      expect(service.isPremiumUnlocked, true);
      expect(service.isPremiumPurchased, false);
    });

    test('別ユーザーの購入状態は影響しない', () async {
      await service.initialize(userId: 'user1');
      service.setPremiumStatus('user2', true);

      expect(service.isPremiumUnlocked, false);
    });
  });

  group('debugSetPremiumOverride', () {
    test('trueに設定するとisPremiumUnlockedがtrue', () {
      service.debugSetPremiumOverride(true);

      expect(service.isPremiumUnlocked, true);
      expect(service.isDebugPremiumOverrideActive, true);
    });

    test('falseに設定するとisPremiumUnlockedがfalse', () {
      service.debugSetPremiumOverride(false);

      expect(service.isPremiumUnlocked, false);
      expect(service.isDebugPremiumOverrideActive, true);
    });

    test('nullに設定するとオーバーライドが解除される', () {
      service.debugSetPremiumOverride(true);
      service.debugSetPremiumOverride(null);

      expect(service.isPremiumUnlocked, false);
      expect(service.isDebugPremiumOverrideActive, false);
    });

    test('オーバーライドが購入状態より優先される', () async {
      await service.initialize(userId: 'user1');
      service.setPremiumStatus('user1', true);
      service.debugSetPremiumOverride(false);

      expect(service.isPremiumUnlocked, false);
    });

    test('オーバーライドが体験期間より優先される', () {
      service.startTrial(7);
      service.debugSetPremiumOverride(false);

      expect(service.isPremiumUnlocked, false);
    });

    test('notifyListenersが呼ばれる', () {
      var notified = false;
      service.addListener(() => notified = true);

      service.debugSetPremiumOverride(true);

      expect(notified, true);
    });
  });

  group('体験期間', () {
    test('startTrialで体験期間を開始', () {
      service.startTrial(7);

      expect(service.isTrialActive, true);
      expect(service.isTrialEverStarted, true);
      expect(service.trialStartDate, isNotNull);
      expect(service.trialEndDate, isNotNull);
    });

    test('開始日と終了日の差が指定日数', () {
      service.startTrial(7);

      final diff = service.trialEndDate!.difference(service.trialStartDate!);
      expect(diff.inDays, 7);
    });

    test('endTrialで体験期間を終了', () {
      service.startTrial(7);
      service.endTrial();

      expect(service.isTrialActive, false);
      expect(service.trialStartDate, isNull);
      expect(service.trialEndDate, isNull);
    });

    test('終了後もisTrialEverStartedはtrue', () {
      service.startTrial(7);
      service.endTrial();

      expect(service.isTrialEverStarted, true);
    });

    test('二重開始が防止される', () {
      service.startTrial(7);
      final firstEndDate = service.trialEndDate;

      service.startTrial(14);

      expect(service.trialEndDate, firstEndDate);
    });

    test('残り時間が取得できる', () {
      service.startTrial(7);

      final remaining = service.trialRemainingDuration;

      expect(remaining, isNotNull);
      expect(remaining!.inDays, greaterThanOrEqualTo(6));
    });

    test('notifyListenersが呼ばれる', () {
      var notifyCount = 0;
      service.addListener(() => notifyCount++);

      service.startTrial(7);

      expect(notifyCount, greaterThan(0));
    });
  });

  group('clearError', () {
    test('エラーをクリアする', () {
      service.clearError();

      expect(service.error, isNull);
    });

    test('notifyListenersが呼ばれる', () {
      var notified = false;
      service.addListener(() => notified = true);

      service.clearError();

      expect(notified, true);
    });
  });

  group('resetForLogout', () {
    test('ユーザーIDがリセットされる', () async {
      await service.initialize(userId: 'user1');
      service.setPremiumStatus('user1', true);
      expect(service.isPremiumUnlocked, true);

      service.resetForLogout();

      expect(service.isPremiumUnlocked, false);
    });

    test('notifyListenersが呼ばれる', () {
      var notified = false;
      service.addListener(() => notified = true);

      service.resetForLogout();

      expect(notified, true);
    });
  });

  group('purchaseProduct / restorePurchases', () {
    test('purchaseProductがfalseを返す（Fakeではストア不可）', () async {
      final result = await service.purchaseProduct(OneTimePurchase.premium);

      expect(result, false);
    });

    test('restorePurchasesがfalseを返す（Fakeではストア不可）', () async {
      final result = await service.restorePurchases();

      expect(result, false);
    });
  });

  group('OneTimePurchaseServiceインターフェース準拠', () {
    test('FakeがOneTimePurchaseServiceを実装している', () {
      expect(service, isA<OneTimePurchaseService>());
    });

    test('FakeがChangeNotifierを実装している', () {
      expect(service, isA<ChangeNotifier>());
    });
  });
}
