// 買い切り型アプリ内課金による機能制御システム
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:maikago/services/one_time_purchase_service.dart';

/// 機能制限の種類
enum FeatureType {
  themeCustomization, // テーマカスタマイズ
  fontCustomization, // フォントカスタマイズ
  adRemoval, // 広告削除
  ocrUnlimited, // OCR無制限
  shopUnlimited, // ショップ無制限
  recipeParser, // レシピ解析
}

/// 制限に達した際の案内タイプ
enum LimitReachedType {
  themeLimit, // テーマ制限
  fontLimit, // フォント制限
  featureLocked, // 機能ロック
}

/// 買い切り型アプリ内課金による機能制御システム
/// - 買い切り型アプリ内課金に基づく機能制御
/// - 制限に達した際の優しい案内機能
/// - アップグレード促進機能
/// - 使用状況の可視化機能
class FeatureAccessControl extends ChangeNotifier {
  late OneTimePurchaseService _purchaseService;

  // OCR月間使用制限
  static const int maxFreeOcrPerMonth = 5;
  int _ocrMonthlyUsageCount = 0;
  String _ocrCountMonth = ''; // 'YYYY-MM' format

  // ショップ数制限
  static const int maxFreeShops = 2;

  /// 初期化
  Future<void> initialize(OneTimePurchaseService purchaseService) async {
    _purchaseService = purchaseService;
    _purchaseService.addListener(_onPurchaseChanged);
    await _loadOcrUsageFromLocal();
  }

  /// 購入状態変更時の処理
  void _onPurchaseChanged() {
    notifyListeners();
  }

  /// 現在のプラン情報を取得
  Map<String, dynamic> get currentPlanInfo => {
        'isPremium': _purchaseService.isPremiumUnlocked,
        'isTrialActive': _purchaseService.isTrialActive,
        'trialRemainingDuration':
            _purchaseService.trialRemainingDuration?.toString(),
      };

  /// プレミアム機能が利用可能かどうか
  bool get isPremiumUnlocked => _purchaseService.isPremiumUnlocked;

  /// テーマカスタマイズが利用可能かどうか
  bool canCustomizeTheme() {
    return _purchaseService.isPremiumUnlocked;
  }

  /// フォントカスタマイズが利用可能かどうか
  bool canCustomizeFont() {
    return _purchaseService.isPremiumUnlocked;
  }

  /// 広告が表示されるかどうか
  bool shouldShowAds() {
    return !_purchaseService.isPremiumUnlocked;
  }

  // ===== OCR月間使用制限 =====

  /// OCR残り回数を取得
  int get ocrRemainingCount {
    if (isPremiumUnlocked) return 999;
    _checkAndResetMonthlyOcr();
    return (maxFreeOcrPerMonth - _ocrMonthlyUsageCount)
        .clamp(0, maxFreeOcrPerMonth);
  }

  /// OCRが利用可能かどうか
  bool canUseOcr() {
    if (isPremiumUnlocked) return true;
    _checkAndResetMonthlyOcr();
    return _ocrMonthlyUsageCount < maxFreeOcrPerMonth;
  }

  /// OCR使用回数をインクリメント
  void incrementOcrUsage() {
    if (isPremiumUnlocked) return;
    _checkAndResetMonthlyOcr();
    _ocrMonthlyUsageCount++;
    _saveOcrUsageToLocal();
    notifyListeners();
  }

  /// OCR月間カウントをリセット
  void resetMonthlyOcrCount() {
    _ocrMonthlyUsageCount = 0;
    _ocrCountMonth = _currentMonth();
    _saveOcrUsageToLocal();
    notifyListeners();
  }

  /// 月が変わっていたらカウントをリセット
  void _checkAndResetMonthlyOcr() {
    final currentMonth = _currentMonth();
    if (_ocrCountMonth != currentMonth) {
      _ocrMonthlyUsageCount = 0;
      _ocrCountMonth = currentMonth;
      _saveOcrUsageToLocal();
    }
  }

  /// 現在の月を 'YYYY-MM' 形式で取得
  String _currentMonth() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  /// OCR使用状況をSharedPreferencesに保存
  Future<void> _saveOcrUsageToLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('ocr_monthly_usage_count', _ocrMonthlyUsageCount);
    await prefs.setString('ocr_count_month', _ocrCountMonth);
  }

  /// OCR使用状況をSharedPreferencesから読み込み
  Future<void> _loadOcrUsageFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    _ocrMonthlyUsageCount = prefs.getInt('ocr_monthly_usage_count') ?? 0;
    _ocrCountMonth = prefs.getString('ocr_count_month') ?? '';
    _checkAndResetMonthlyOcr();
  }

  // ===== ショップ数制限 =====

  /// ショップを作成できるかどうか
  bool canCreateShop({required int currentShopCount}) {
    if (isPremiumUnlocked) return true;
    return currentShopCount < maxFreeShops;
  }

  // ===== レシピ解析（プレミアム限定） =====

  /// レシピ解析が利用可能かどうか
  bool canUseRecipeParser() => isPremiumUnlocked;

  /// 機能が利用可能かどうかをチェック
  bool isFeatureAvailable(FeatureType featureType) {
    switch (featureType) {
      case FeatureType.themeCustomization:
        return canCustomizeTheme();
      case FeatureType.fontCustomization:
        return canCustomizeFont();
      case FeatureType.adRemoval:
        return !shouldShowAds();
      case FeatureType.ocrUnlimited:
        return canUseOcr();
      case FeatureType.shopUnlimited:
        return isPremiumUnlocked;
      case FeatureType.recipeParser:
        return canUseRecipeParser();
    }
  }

  /// 機能がロックされているかどうかをチェック
  bool isFeatureLocked(FeatureType featureType) {
    return !isFeatureAvailable(featureType);
  }

  /// 機能制限に達したかどうかをチェック
  bool hasReachedLimit(LimitReachedType limitType) {
    switch (limitType) {
      case LimitReachedType.themeLimit:
        return !canCustomizeTheme();
      case LimitReachedType.fontLimit:
        return !canCustomizeFont();
      case LimitReachedType.featureLocked:
        return false; // 基本的に機能ロックなし
    }
  }

  /// 推奨アップグレードプランを取得
  Map<String, dynamic> getRecommendedUpgradePlan([FeatureType? featureType]) {
    if (isPremiumUnlocked) {
      // すでにプレミアム機能を利用中
      return {
        'type': 'premium',
        'name': 'まいかごプレミアム',
        'description': 'すべてのプレミアム機能を利用可能',
        'price': 500,
        'isAlreadyOwned': true,
      };
    } else {
      // プレミアム機能を推奨
      return {
        'type': 'premium',
        'name': 'まいかごプレミアム',
        'description': 'すべてのプレミアム機能を利用可能',
        'price': 500,
        'isAlreadyOwned': false,
        'features': [
          'OCR（値札撮影）無制限',
          'ショップ（タブ）無制限',
          'レシピ解析',
          '全テーマ・全フォント',
          '広告完全非表示',
        ],
      };
    }
  }

  /// 機能の説明を取得
  String getFeatureDescription(FeatureType featureType) {
    switch (featureType) {
      case FeatureType.themeCustomization:
        return 'テーマカスタマイズ';
      case FeatureType.fontCustomization:
        return 'フォントカスタマイズ';
      case FeatureType.adRemoval:
        return '広告非表示';
      case FeatureType.ocrUnlimited:
        return 'OCR無制限';
      case FeatureType.shopUnlimited:
        return 'ショップ無制限';
      case FeatureType.recipeParser:
        return 'レシピ解析';
    }
  }

  /// 制限タイプの説明を取得
  String getLimitDescription(LimitReachedType limitType) {
    switch (limitType) {
      case LimitReachedType.themeLimit:
        return 'テーマ制限';
      case LimitReachedType.fontLimit:
        return 'フォント制限';
      case LimitReachedType.featureLocked:
        return '機能ロック';
    }
  }

  /// 使用状況の統計を取得
  Map<String, dynamic> getUsageStats() {
    return {
      'currentPlan': currentPlanInfo,
      'features': {
        'themeCustomization': {
          'available': canCustomizeTheme(),
          'description': getFeatureDescription(FeatureType.themeCustomization),
        },
        'fontCustomization': {
          'available': canCustomizeFont(),
          'description': getFeatureDescription(FeatureType.fontCustomization),
        },
        'adRemoval': {
          'available': !shouldShowAds(),
          'description': getFeatureDescription(FeatureType.adRemoval),
        },
      },
      'recommendedUpgrade': getRecommendedUpgradePlan(),
    };
  }

  /// デバッグ情報を取得
  Map<String, dynamic> getDebugInfo() {
    return {
      'isPremiumUnlocked': isPremiumUnlocked,
      'isTrialActive': _purchaseService.isTrialActive,
      'trialRemainingDuration':
          _purchaseService.trialRemainingDuration?.toString(),
      'isStoreAvailable': _purchaseService.isStoreAvailable,
      'error': _purchaseService.error,
      'isLoading': _purchaseService.isLoading,
      'currentPlanInfo': currentPlanInfo,
      'usageStats': getUsageStats(),
    };
  }

  @override
  void dispose() {
    _purchaseService.removeListener(_onPurchaseChanged);
    super.dispose();
  }
}
