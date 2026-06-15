// 起動時のスプラッシュ画面。アニメーションとデータ初期ロードの同期を行う
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:async'; // TimeoutException用
import 'package:maikago/providers/data_provider.dart';
import 'package:maikago/providers/auth_provider.dart';
import 'package:maikago/services/debug_service.dart';
import 'package:maikago/utils/theme_utils.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool _isDataLoaded = false; // データロード完了フラグ
  bool _isAnimationComplete = false; // アニメーション完了フラグ
  bool _hasStartedDataLoading = false; // 二重起動防止

  @override
  void initState() {
    super.initState();
    _initializeAnimations();

    // ビルドフェーズ完了後にデータ読み込みを開始
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasStartedDataLoading) {
        _hasStartedDataLoading = true;
        _loadDataAndProceed();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // didChangeDependenciesでは何もしない
  }

  /// フェード＋スケールのアニメーションを初期化
  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _animationController.forward().then((_) {
      _isAnimationComplete = true;
      _checkIfReadyToProceed();
    });
  }

  /// データ読み込みを実行し、完了後に遷移条件をチェック
  Future<void> _loadDataAndProceed() async {
    try {
      // データ読み込みを開始
      final dataProvider = context.read<DataProvider>();
      final authProvider = context.read<AuthProvider>();

      // 認証プロバイダーを設定
      dataProvider.setAuthProvider(authProvider);
      // 未ログイン時・ゲストモード時はローカルモードで動作し、Firestoreへはアクセスしない
      // セキュリティ根拠: 匿名コレクションを禁止するルールに整合、不要な公開範囲を持たない
      dataProvider
          .setLocalMode(!authProvider.isLoggedIn || authProvider.isGuestMode);

      // データ読み込みを実行（45秒でタイムアウト）
      await dataProvider.loadData().timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          DebugService().log('スプラッシュ画面: データ読み込みタイムアウト');
          throw TimeoutException(
              'データ読み込みがタイムアウトしました', const Duration(seconds: 45));
        },
      );

      if (mounted) {
        setState(() {
          _isDataLoaded = true;
        });
        _checkIfReadyToProceed();
      }
    } catch (e) {
      DebugService().log('データ読み込みエラー: $e');
      // エラーが発生しても進める
      if (mounted) {
        setState(() {
          _isDataLoaded = true;
        });
        _checkIfReadyToProceed();
      }
    }
  }

  /// アニメーションとロード完了の両方が揃ったら遷移
  void _checkIfReadyToProceed() {
    // アニメーション完了とデータ読み込み完了の両方が揃ったら進む
    if (_isAnimationComplete && _isDataLoaded) {
      // 最小表示時間を確保（アニメーション完了後）
      Future.delayed(const Duration(milliseconds: 500), () async {
        if (mounted) {
          final authProvider = context.read<AuthProvider>();
          if (authProvider.isLoggedIn || authProvider.isGuestMode) {
            context.go('/home');
          } else {
            context.go('/login');
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.primaryColor,
      body: Center(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // アプリアイコンまたはロゴ
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: colorScheme.onPrimary.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: theme.cardShadowColor,
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.shopping_basket_rounded,
                        size: 70,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 30),
                    // アプリ名
                    Text(
                      'まいカゴ',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onPrimary,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '買い物リスト管理アプリ',
                      style: TextStyle(
                        fontSize: theme.textTheme.bodyLarge?.fontSize,
                        color: colorScheme.onPrimary.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 50),
                    // ローディングインジケーター
                    SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colorScheme.onPrimary.withValues(alpha: 0.8),
                        ),
                        strokeWidth: 2,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // データ読み込み状況を表示
                    if (_isDataLoaded)
                      Text(
                        'データ読み込み完了',
                        style: TextStyle(
                          fontSize: theme.textTheme.bodyMedium?.fontSize,
                          color: colorScheme.onPrimary.withValues(alpha: 0.7),
                        ),
                      )
                    else
                      Text(
                        'データを読み込み中...',
                        style: TextStyle(
                          fontSize: theme.textTheme.bodyMedium?.fontSize,
                          color: colorScheme.onPrimary.withValues(alpha: 0.7),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
