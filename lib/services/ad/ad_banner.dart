import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:maikago/services/one_time_purchase_service.dart';
import 'package:maikago/config.dart';
import 'package:maikago/env.dart';

class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  bool _hasDisposed = false;
  bool _wasPremium = false; // 前回のプレミアム状態を保持
  late final OneTimePurchaseService _purchaseService;

  @override
  void initState() {
    super.initState();
    _purchaseService = context.read<OneTimePurchaseService>();
    // OneTimePurchaseServiceの状態変化を監視
    _wasPremium = _purchaseService.isPremiumUnlocked;
    _purchaseService.addListener(_onPremiumStatusChanged);
    _loadBannerAd();
  }

  void _onPremiumStatusChanged() {
    final isPremium = _purchaseService.isPremiumUnlocked;

    // プレミアム状態に変化がない場合はスキップ
    if (_wasPremium == isPremium) {
      return;
    }

    if (isPremium && _bannerAd != null) {
      _bannerAd?.dispose();
      _bannerAd = null;
      _isLoaded = false;
      _wasPremium = true;
      if (mounted) {
        setState(() {});
      }
    } else if (!isPremium && !_isLoaded) {
      _wasPremium = false;
      _loadBannerAd();
    }
  }

  @override
  void dispose() {
    _hasDisposed = true;
    _purchaseService.removeListener(_onPremiumStatusChanged);
    _bannerAd?.dispose();
    super.dispose();
  }

  Future<void> _loadBannerAd() async {
    if (kIsWeb || _hasDisposed || !mounted) {
      return;
    }
    const bool forceShowAdsForDebug =
        configEnableDebugMode && configForceShowAdsInDebug;

    // OneTimePurchaseServiceの初期化を待つ
    final purchaseService = _purchaseService;
    try {
      await purchaseService.initialized.timeout(const Duration(seconds: 3));
    } catch (_) {
      // タイムアウト時はそのまま続行
    }

    if (_hasDisposed || !mounted) {
      return;
    }

    // プレミアム状態をより確実にチェック
    if (purchaseService.isPremiumUnlocked) {
      if (!forceShowAdsForDebug) {
        return;
      }
    }

    // WebViewの初期化とGoogle Mobile Ads SDKの準備を待つ
    await Future.delayed(const Duration(milliseconds: 2000));
    if (_hasDisposed || !mounted) {
      return;
    }

    unawaited(_bannerAd?.dispose());
    _bannerAd = null;
    _isLoaded = false;

    final bannerAd = BannerAd(
      adUnitId: Env.admobBannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!_hasDisposed && mounted) {
            setState(() {
              _isLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          if (error.message.contains('JavascriptEngine') ||
              error.message.contains('WebView') ||
              error.message.contains('Renderer')) {
            Future.delayed(const Duration(seconds: 10), () {
              if (!_hasDisposed && mounted) {
                _loadBannerAd();
              }
            });
          }

          ad.dispose();
          _bannerAd = null;
          _isLoaded = false;
        },
      ),
    );

    if (_hasDisposed || !mounted) {
      unawaited(bannerAd.dispose());
      return;
    }

    _bannerAd = bannerAd;
    unawaited(_bannerAd?.load());
  }

  @override
  Widget build(BuildContext context) {
    const bool forceShowAdsForDebug =
        configEnableDebugMode && configForceShowAdsInDebug;

    // プレミアム機能で広告非表示の場合は広告を非表示
    final purchaseService = _purchaseService;
    if (purchaseService.isPremiumUnlocked) {
      if (!forceShowAdsForDebug) {
        return const SizedBox.shrink();
      }
    }

    // 広告が読み込まれていない場合も非表示
    if (!_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return RepaintBoundary(
      child: SizedBox(
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      ),
    );
  }
}
