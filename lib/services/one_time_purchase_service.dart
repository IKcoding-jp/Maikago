import 'package:flutter/foundation.dart'
    show
        kIsWeb,
        ChangeNotifier,
        defaultTargetPlatform,
        TargetPlatform,
        visibleForTesting;
import 'package:firebase_core/firebase_core.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:crypto/crypto.dart';
import 'dart:async';
import 'dart:convert';
import 'package:maikago/models/one_time_purchase.dart';
import 'package:maikago/services/debug_service.dart';
import 'package:maikago/services/purchase/trial_manager.dart';
import 'package:maikago/services/purchase/purchase_persistence.dart';
import 'package:maikago/services/purchase/purchase_validator.dart';
import 'package:maikago/services/purchase/purchase_verifier.dart';
import 'package:maikago/services/purchase/restore_coordinator.dart';

/// 非消耗型アプリ内課金管理サービス
class OneTimePurchaseService extends ChangeNotifier {
  OneTimePurchaseService({
    PurchaseVerifier? purchaseVerifier,
    PurchasePersistence? persistence,
  })  : _persistence = persistence ?? PurchasePersistence(),
        _purchaseVerifier =
            purchaseVerifier ?? CloudFunctionsPurchaseVerifier() {
    _trialManager = TrialManager(
      onStateChanged: _onTrialStateChanged,
    );
  }

  final PurchasePersistence _persistence;
  final PurchaseVerifier _purchaseVerifier;
  late final TrialManager _trialManager;

  /// サーバー未検証だがレガシーのプレミアムフラグが残っているユーザー向けに、
  /// 起動時に自動再検証（restorePurchases）が必要かどうか（Issue #163 移行）。
  bool _needsServerReverification = false;

  // 遅延初期化: 実際にストアが必要になるまで InAppPurchase.instance に触れない
  // （構築しただけで課金クライアント接続を開始させない。テスト容易性も向上）。
  InAppPurchase? _inAppPurchaseInstance;
  InAppPurchase get _inAppPurchase =>
      _inAppPurchaseInstance ??= InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  bool _isStoreAvailable = false;

  final Set<String> _androidProductIds = {
    'maikago_premium_unlock',
  };

  final Map<String, ProductDetails> _productIdToDetails = {};
  final RestoreCoordinator _restoreCoordinator = RestoreCoordinator();

  // 購入済み機能の状態
  final Map<String, bool> _userPremiumStatus = {};
  String _currentUserId = '';

  // デバイスフィンガープリント
  String? _deviceFingerprint;

  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;
  final Completer<void> _initCompleter = Completer<void>();

  // デバッグ用プレミアム切り替え（kDebugModeでのみ有効）
  bool? _debugPremiumOverride;

  /// デバッグ用: プレミアム状態を強制切り替え（nullでリセット）
  void debugSetPremiumOverride(bool? value) {
    _debugPremiumOverride = value;
    notifyListeners();
  }

  bool get isDebugPremiumOverrideActive => _debugPremiumOverride != null;

  // Getters
  bool get isPremiumUnlocked =>
      _debugPremiumOverride ??
      ((_userPremiumStatus[_currentUserId] ?? false) ||
          _trialManager.isTrialActive);
  bool get isPremiumPurchased =>
      _userPremiumStatus[_currentUserId] ?? false; // 実際の購入状態（体験期間除く）
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isStoreAvailable => _isStoreAvailable;
  bool get isInitialized => _isInitialized;

  /// 初期化完了を待機するFuture
  Future<void> get initialized => _initCompleter.future;

  // 体験期間のgetter（TrialManagerに委譲）
  bool get isTrialActive => _trialManager.isTrialActive;
  bool get isTrialEverStarted => _trialManager.isTrialEverStarted;
  DateTime? get trialStartDate => _trialManager.trialStartDate;
  DateTime? get trialEndDate => _trialManager.trialEndDate;

  // 体験期間の残り時間を取得
  Duration? get trialRemainingDuration => _trialManager.trialRemainingDuration;

  /// デバイスフィンガープリントを生成
  Future<String> _generateDeviceFingerprint() async {
    try {
      // WebプラットフォームではSharedPreferencesを使用（DeviceInfoPluginは使用しない）
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        String? storedId = prefs.getString('device_fingerprint');
        if (storedId == null) {
          storedId = sha256
              .convert(utf8.encode(
                  '${DateTime.now().millisecondsSinceEpoch}_${Uri.base.host}'))
              .toString();
          await prefs.setString('device_fingerprint', storedId);
        }
        return storedId;
      }

      // ネイティブプラットフォームではDeviceInfoを使用
      String deviceId = '';
      try {
        final deviceInfo = DeviceInfoPlugin();
        if (defaultTargetPlatform == TargetPlatform.android) {
          final androidInfo = await deviceInfo.androidInfo;
          final rawId = '${androidInfo.id}_${androidInfo.model}';
          deviceId = sha256.convert(utf8.encode(rawId)).toString();
        } else if (defaultTargetPlatform == TargetPlatform.iOS) {
          final iosInfo = await deviceInfo.iosInfo;
          deviceId = sha256
              .convert(utf8.encode(iosInfo.identifierForVendor ?? 'unknown'))
              .toString();
        }
      } catch (e) {
        DebugService().logError('デバイス情報取得エラー: $e');
      }

      // デバイス情報が取得できなかった場合、SharedPreferencesを使用
      if (deviceId.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        String? storedId = prefs.getString('device_fingerprint');
        if (storedId == null) {
          storedId = sha256
              .convert(utf8
                  .encode('${DateTime.now().millisecondsSinceEpoch}_fallback'))
              .toString();
          await prefs.setString('device_fingerprint', storedId);
        }
        deviceId = storedId;
      }

      return deviceId;
    } catch (e) {
      DebugService().logError('デバイスフィンガープリント生成エラー: $e');
      // フォールバック: タイムスタンプベースのID
      return sha256
          .convert(
              utf8.encode('${DateTime.now().millisecondsSinceEpoch}_fallback'))
          .toString();
    }
  }

  /// 初期化
  Future<void> initialize({String? userId}) async {
    if (_isInitialized) {
      DebugService().logWarning('非消耗型アプリ内課金サービスは既に初期化済みです');
      if (userId != null) {
        _currentUserId = userId;
        await _loadFromFirestore();
        _maybeTriggerServerReverification();
        notifyListeners(); // ユーザーID変更時の通知を追加
      }
      return;
    }
    try {
      await _initializeStore();
      await _loadFromLocalStorage();
      _currentUserId = userId ?? _persistence.auth?.currentUser?.uid ?? '';

      // デバイスフィンガープリントを生成
      _deviceFingerprint = await _generateDeviceFingerprint();

      if (Firebase.apps.isNotEmpty) {
        await _loadFromFirestore();
        _maybeTriggerServerReverification();
      }
      DebugService().logInfo('非消耗型アプリ内課金初期化完了');
      // 初期化時に体験期間タイマーをセット
      _trialManager.startTrialTimer();
      _isInitialized = true;
      if (!_initCompleter.isCompleted) _initCompleter.complete();
      notifyListeners();
    } catch (e) {
      DebugService().logError('非消耗型アプリ内課金初期化エラー: $e');
      _setError('初期化に失敗しました: $e');
      _isInitialized = true;
      if (!_initCompleter.isCompleted) _initCompleter.complete();
      notifyListeners();
    }
  }

  /// ストア初期化（In-App Purchase）
  Future<void> _initializeStore() async {
    try {
      // WebプラットフォームではIAPをスキップ
      if (kIsWeb) {
        _isStoreAvailable = false;
        return;
      }

      // プラットフォームチェック（Web以外）
      try {
        if (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS) {
          _isStoreAvailable = false;
          return;
        }
      } catch (e) {
        DebugService().logError('プラットフォーム判定エラー: $e');
        _isStoreAvailable = false;
        return;
      }

      _isStoreAvailable = await _inAppPurchase.isAvailable();
      if (!_isStoreAvailable) {
        return;
      }

      // 購入ストリーム購読
      _purchaseSubscription ??= _inAppPurchase.purchaseStream.listen(
        _onPurchaseUpdated,
        onError: (Object error) {
          DebugService().logError('非消耗型購入ストリームエラー: $error');
        },
      );

      // 商品情報取得
      await _queryProductDetails();
    } catch (e) {
      DebugService().logError('非消耗型IAP初期化エラー: $e');
      _isStoreAvailable = false;
      // エラーを再スローせず、ローカルモードで継続
    }
  }

  /// 商品情報を取得
  Future<void> _queryProductDetails() async {
    if (!_isStoreAvailable) return;

    try {
      final response =
          await _inAppPurchase.queryProductDetails(_androidProductIds);

      if (response.notFoundIDs.isNotEmpty) {
        DebugService().logWarning('見つからない商品ID: ${response.notFoundIDs}');
      }

      _productIdToDetails.clear();

      for (final productDetails in response.productDetails) {
        _productIdToDetails[productDetails.id] = productDetails;
      }
    } catch (e) {
      DebugService().logError('非消耗型商品情報取得エラー: $e');
    }
  }

  /// 購入更新の処理
  Future<void> _onPurchaseUpdated(
      List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        await _handleSuccessfulPurchase(purchaseDetails);
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        DebugService().logError('非消耗型購入エラー: ${purchaseDetails.error}');
        _setError('購入に失敗しました: ${purchaseDetails.error?.message}');
      }

      // 購入完了の確認
      if (purchaseDetails.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchaseDetails);
      }
    }
  }

  /// 成功した購入の処理
  Future<void> _handleSuccessfulPurchase(
      PurchaseDetails purchaseDetails) async {
    // クライアント側の一次検証: 不正・未完了の購入情報ではプレミアムを有効化しない。
    if (!PurchaseValidator.isValidPremiumPurchase(purchaseDetails)) {
      DebugService().logWarning(
          '不正または未完了の購入情報を拒否: ${purchaseDetails.productID} / ${purchaseDetails.status}');
      return;
    }

    // サーバー側レシート検証（Issue #163 対応案#1/#3）。
    // Android はサーバー検証を必須とし、検証成功時のみプレミアムを付与する。
    // サーバーは検証成功時に premium_entitlement（サーバー専用ドキュメント）へ
    // 書き込むため、クライアント改竄では付与できない。
    // iOS はサーバー検証が未実装のため、当面はクライアント一次検証のみで付与する
    // （TODO #163: App Store Server API 対応時に Android と同様の必須化を行う）。
    final isIos = defaultTargetPlatform == TargetPlatform.iOS;
    if (!isIos) {
      try {
        final result = await _purchaseVerifier.verify(
          platform: 'android',
          productId: purchaseDetails.productID,
          purchaseToken:
              purchaseDetails.verificationData.serverVerificationData,
        );
        if (!result.verified) {
          DebugService().logWarning(
              'サーバー購入検証に失敗（プレミアム付与せず）: ${purchaseDetails.productID}');
          _setError('購入を検証できませんでした。時間をおいて再試行してください。');
          return;
        }
      } on PurchaseVerificationException catch (e) {
        DebugService().logError('サーバー購入検証エラー: ${e.code}');
        _setError('購入の検証に失敗しました。時間をおいて再試行してください。');
        return;
      }
    }

    // 検証通過 → 購入済み機能を更新
    if (PurchaseValidator.premiumProductIds
        .contains(purchaseDetails.productID)) {
      _userPremiumStatus[_currentUserId] = true;
    }

    // 復元イベントなら待機中の復元処理（restorePurchases）を完了させる
    if (purchaseDetails.status == PurchaseStatus.restored) {
      _restoreCoordinator.signalRestored();
    }

    // ローカルストレージにキャッシュ（オフライン表示用）。プレミアムの最終ソースは
    // サーバーの premium_entitlement であり、次回ロード時に上書きされる。
    await _saveToLocalStorage();

    notifyListeners();
    DebugService().logInfo('購入検証成功・プレミアム付与: ${purchaseDetails.productID}');
  }

  /// テスト用: 現在のユーザーIDを直接設定する。
  @visibleForTesting
  void setCurrentUserIdForTest(String userId) {
    _currentUserId = userId;
  }

  /// テスト用: 購入成功時の内部処理を直接呼び出す。
  @visibleForTesting
  Future<void> handleSuccessfulPurchaseForTest(PurchaseDetails details) {
    return _handleSuccessfulPurchase(details);
  }

  /// テスト用: デバイスフィンガープリントを直接設定する。
  @visibleForTesting
  set deviceFingerprintForTest(String value) => _deviceFingerprint = value;

  /// テスト用: Firestore読み込み（移行判定含む）を直接呼び出す。
  @visibleForTesting
  Future<void> loadFromFirestoreForTest() => _loadFromFirestore();

  /// テスト用: 自動再検証が必要と判定されたか。
  @visibleForTesting
  bool get needsServerReverificationForTest => _needsServerReverification;

  /// 商品を購入
  Future<bool> purchaseProduct(OneTimePurchase purchase) async {
    try {
      _setLoading(true);
      clearError();

      if (!_isStoreAvailable) {
        _setError('ストアが利用できません。ネットワークやGoogle Playの状態を確認してください。');
        return false;
      }

      // 商品情報を再取得して最新の状態を確認
      await _queryProductDetails();

      final productDetails = _productIdToDetails[purchase.productId];
      if (productDetails == null) {
        _setError('商品情報が見つかりません: ${purchase.productId}');
        return false;
      }

      // 購入リクエストを作成
      final purchaseParam = PurchaseParam(productDetails: productDetails);

      // 購入を実行
      final success =
          await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);

      if (!success) {
        _setError('購入リクエストの送信に失敗しました');
      }

      return success;
    } catch (e) {
      DebugService().logError('非消耗型購入エラー: $e');
      _setError('購入に失敗しました: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// 購入を復元
  Future<bool> restorePurchases() async {
    try {
      _setLoading(true);
      clearError();

      if (!_isStoreAvailable) {
        _setError('ストアが利用できません。');
        return false;
      }

      // 復元完了待ち・タイムアウト・再試行のためのリセットは
      // RestoreCoordinator に委譲（タイムアウト時に Completer を放置せず、
      // 再試行が正常動作することを保証する。Issue #163）
      final result = await _restoreCoordinator.wait(
        () => _inAppPurchase.restorePurchases(),
      );

      if (!result) {
        DebugService().logError('非消耗型購入復元タイムアウト');
      }

      return result;
    } catch (e) {
      DebugService().logError('非消耗型購入復元エラー: $e');
      _setError('購入復元に失敗しました: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// ローカルストレージから読み込み（PurchasePersistenceに委譲）
  Future<void> _loadFromLocalStorage() async {
    final data = await _persistence.loadFromLocalStorage();

    _userPremiumStatus
      ..clear()
      ..addAll(data.userPremiumStatus);

    // TrialManagerに体験期間の状態を復元
    _trialManager.restoreState(
      isActive: data.isTrialActive,
      isEverStarted: data.isTrialEverStarted,
      startDate: data.trialStartDate,
      endDate: data.trialEndDate,
    );

    // 体験期間が期限切れの場合は終了
    _trialManager.checkAndExpireIfNeeded();
  }

  /// ローカルストレージに保存（PurchasePersistenceに委譲）
  Future<void> _saveToLocalStorage() async {
    await _persistence.saveToLocalStorage(
      userPremiumStatus: _userPremiumStatus,
      isTrialActive: _trialManager.isTrialActive,
      isTrialEverStarted: _trialManager.isTrialEverStarted,
      trialStartDate: _trialManager.trialStartDate,
      trialEndDate: _trialManager.trialEndDate,
    );
  }

  /// Firestoreから読み込み（PurchasePersistenceに委譲）
  ///
  /// プレミアム判定の信頼できる唯一のソースは、サーバー検証済みの
  /// premium_entitlement（Issue #163 対応案#3）。レガシーのクライアント
  /// フラグ（premium_status_map）は移行判定にのみ使う。
  Future<void> _loadFromFirestore() async {
    if (_currentUserId.isEmpty || _deviceFingerprint == null) return;

    // サーバー検証済みエンタイトルメント（信頼できる唯一のソース）
    final isPremiumVerified =
        await _persistence.loadServerEntitlement(userId: _currentUserId);

    // 体験期間履歴 + レガシーフラグ（移行判定用）
    final data = await _persistence.loadFromFirestore(
      userId: _currentUserId,
      deviceFingerprint: _deviceFingerprint!,
    );

    final hasLegacyPremium = data?.isPremium ?? false;
    if (data != null && data.isTrialEverStarted) {
      _trialManager.markAsEverStarted();
    }

    final isIos = defaultTargetPlatform == TargetPlatform.iOS;
    if (isIos) {
      // iOSはサーバー検証が未実装。既存挙動を壊さないよう、サーバー検証済み
      // またはレガシーフラグのいずれかでプレミアムとする（自動再検証はしない）。
      _userPremiumStatus[_currentUserId] =
          isPremiumVerified || hasLegacyPremium;
      _needsServerReverification = false;
    } else {
      // Androidはサーバー検証済みフラグのみを信頼。レガシーフラグだけが立つ
      // 既存ユーザーは、起動時の自動再検証でシームレスに移行する。
      _userPremiumStatus[_currentUserId] = isPremiumVerified;
      _needsServerReverification = !isPremiumVerified && hasLegacyPremium;
    }
  }

  /// レガシープレミアムの自動再検証を必要なら起動する（Issue #163 移行）。
  ///
  /// サーバー検証済みフラグがなく、レガシーのクライアントフラグだけが残る
  /// 既存ユーザーに対し、restorePurchases を自動実行してサーバー再検証へ導く。
  void _maybeTriggerServerReverification() {
    if (_needsServerReverification && _isStoreAvailable) {
      _needsServerReverification = false;
      DebugService().logInfo('レガシープレミアムの自動再検証を開始（Issue #163移行）');
      // 結果は purchaseStream 経由で _handleSuccessfulPurchase が受け、
      // サーバー検証→entitlement付与まで進む。失敗してもUIは継続。
      unawaited(restorePurchases());
    }
  }

  /// Firestoreに保存（PurchasePersistenceに委譲）
  Future<void> _saveToFirestore() async {
    if (_currentUserId.isEmpty || _deviceFingerprint == null) return;

    await _persistence.saveToFirestore(
      userId: _currentUserId,
      deviceFingerprint: _deviceFingerprint!,
      isPremium: _userPremiumStatus[_currentUserId] ?? false,
      isTrialEverStarted: _trialManager.isTrialEverStarted,
      trialStartDate: _trialManager.trialStartDate,
      trialEndDate: _trialManager.trialEndDate,
    );
  }

  /// TrialManagerの状態変更コールバック
  void _onTrialStateChanged() {
    _saveToLocalStorage();
    _saveToFirestore();
    notifyListeners();
  }

  /// エラーをクリア
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// エラーを設定
  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  /// ローディング状態を設定
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// 体験期間を開始（TrialManagerに委譲）
  void startTrial(int trialDays) {
    _trialManager.startTrial(trialDays);
  }

  /// 体験期間を終了（TrialManagerに委譲）
  void endTrial() {
    _trialManager.endTrial();
  }

  /// ログアウト時にプレミアム状態をリセット
  void resetForLogout() {
    _currentUserId = '';
    notifyListeners();
  }

  /// リソースを解放
  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    _trialManager.dispose();
    super.dispose();
  }
}
