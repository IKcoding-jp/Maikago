import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:maikago/providers/auth_provider.dart';
import 'package:maikago/providers/theme_provider.dart';
import 'package:maikago/screens/splash_screen.dart';
import 'package:maikago/screens/login_screen.dart';
import 'package:maikago/screens/main_screen.dart';
import 'package:maikago/screens/drawer/about_screen.dart';
import 'package:maikago/screens/drawer/usage_screen.dart';
import 'package:maikago/screens/drawer/calculator_screen.dart';
import 'package:maikago/screens/drawer/maikago_premium.dart';
import 'package:maikago/screens/drawer/feedback_screen.dart';
import 'package:maikago/screens/release_history_screen.dart';
import 'package:maikago/screens/drawer/settings/settings_screen.dart';
import 'package:maikago/screens/drawer/settings/account_screen.dart';
import 'package:maikago/screens/drawer/settings/font_select_screen.dart';
import 'package:maikago/screens/drawer/settings/font_size_select_screen.dart';
import 'package:maikago/screens/drawer/settings/advanced_settings_screen.dart';
import 'package:maikago/screens/drawer/settings/terms_of_service_screen.dart';
import 'package:maikago/screens/drawer/settings/privacy_policy_screen.dart';
import 'package:maikago/screens/camera_screen.dart';
import 'package:maikago/screens/recipe_confirm_screen.dart';
import 'package:maikago/services/recipe_parser_service.dart';
import 'package:maikago/screens/drawer/settings/theme_select_screen.dart';

/// アプリ全体のルーティング定義
///
/// 全ての画面遷移を一元管理する。認証リダイレクトも含む。
GoRouter createAppRouter(AuthProvider authProvider) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: authProvider,
    redirect: (context, state) {
      final isLoggedIn = authProvider.isLoggedIn;
      final isGuestMode = authProvider.isGuestMode;
      final isLoading = authProvider.isLoading;
      final location = state.matchedLocation;

      // スプラッシュ画面は常にアクセス可能
      if (location == '/') return null;

      // 認証状態の読み込み中はリダイレクトしない
      if (isLoading) return null;

      // ログイン済みまたはゲストモードでログイン画面にいる場合はホームへ
      if ((isLoggedIn || isGuestMode) && location == '/login') return '/home';

      // 未ログインかつゲストモードでもない場合はログインへ
      if (!isLoggedIn && !isGuestMode && location != '/login') return '/login';

      return null;
    },
    routes: [
      // --- 認証フロー ---
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginScreen(
          onLoginSuccess: () => context.go('/home'),
        ),
      ),

      // --- メイン画面 ---
      GoRoute(
        path: '/home',
        builder: (context, state) => const MainScreen(),
      ),

      // --- ドロワーメニュー画面 ---
      GoRoute(
        path: '/about',
        builder: (context, state) => const AboutScreen(),
      ),
      GoRoute(
        path: '/usage',
        builder: (context, state) => const UsageScreen(),
      ),
      GoRoute(
        path: '/calculator',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final tp = context.read<ThemeProvider>();
          return CalculatorScreen(
            currentTheme: extra?['currentTheme'] as String? ?? tp.selectedTheme,
            theme: extra?['theme'] as ThemeData? ?? Theme.of(context),
          );
        },
      ),
      GoRoute(
        path: '/subscription',
        builder: (context, state) => const SubscriptionScreen(),
      ),
      GoRoute(
        path: '/feedback',
        builder: (context, state) => const FeedbackScreen(),
      ),
      GoRoute(
        path: '/release-history',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final tp = context.read<ThemeProvider>();
          return ReleaseHistoryScreen(
            currentTheme: extra?['currentTheme'] as String? ?? tp.selectedTheme,
            currentFont: extra?['currentFont'] as String? ?? tp.selectedFont,
            currentFontSize:
                extra?['currentFontSize'] as double? ?? tp.fontSize,
          );
        },
      ),

      // --- 設定画面 ---
      GoRoute(
        path: '/settings',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final tp = context.read<ThemeProvider>();
          return SettingsScreen(
            currentTheme: tp.selectedTheme,
            currentFont: tp.selectedFont,
            currentFontSize: tp.fontSize,
            onThemeChanged: extra?['onThemeChanged'] as ValueChanged<String>? ??
                (themeKey) => tp.updateTheme(themeKey),
            onFontChanged: extra?['onFontChanged'] as ValueChanged<String>? ??
                (font) => tp.updateFont(font),
            onFontSizeChanged:
                extra?['onFontSizeChanged'] as ValueChanged<double>? ??
                    (fontSize) => tp.updateFontSize(fontSize),
            onCustomThemeChanged: extra?['onCustomThemeChanged']
                as ValueChanged<Map<String, Color>>?,
            onDarkModeChanged:
                extra?['onDarkModeChanged'] as ValueChanged<bool>? ??
                    (isDark) {},
            isDarkMode: Theme.of(context).brightness == Brightness.dark,
            theme: Theme.of(context),
          );
        },
      ),
      GoRoute(
        path: '/settings/account',
        builder: (context, state) => const AccountScreen(),
      ),
      GoRoute(
        path: '/settings/theme',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final tp = context.read<ThemeProvider>();
          return ThemeSelectScreen(
            currentTheme: extra?['currentTheme'] as String? ?? tp.selectedTheme,
            theme: extra?['theme'] as ThemeData?,
            onThemeChanged: extra?['onThemeChanged'] as ValueChanged<String>? ??
                (theme) => tp.updateTheme(theme),
          );
        },
      ),
      GoRoute(
        path: '/settings/font',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final tp = context.read<ThemeProvider>();
          return FontSelectScreen(
            currentFont: extra?['currentFont'] as String? ?? tp.selectedFont,
            theme: extra?['theme'] as ThemeData?,
            onFontChanged: extra?['onFontChanged'] as ValueChanged<String>? ??
                (font) => tp.updateFont(font),
          );
        },
      ),
      GoRoute(
        path: '/settings/font-size',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final tp = context.read<ThemeProvider>();
          return FontSizeSelectScreen(
            currentFontSize:
                extra?['currentFontSize'] as double? ?? tp.fontSize,
            theme: extra?['theme'] as ThemeData? ?? tp.themeData,
            onFontSizeChanged:
                extra?['onFontSizeChanged'] as ValueChanged<double>? ??
                    (fontSize) => tp.updateFontSize(fontSize),
          );
        },
      ),
      GoRoute(
        path: '/settings/advanced',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final tp = context.read<ThemeProvider>();
          return AdvancedSettingsScreen(
            currentTheme: extra?['currentTheme'] as String? ?? tp.selectedTheme,
            currentFont: extra?['currentFont'] as String? ?? tp.selectedFont,
            currentFontSize:
                extra?['currentFontSize'] as double? ?? tp.fontSize,
            theme: extra?['theme'] as ThemeData?,
          );
        },
      ),
      GoRoute(
        path: '/settings/terms',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final tp = context.read<ThemeProvider>();
          return TermsOfServiceScreen(
            currentTheme: extra?['currentTheme'] as String? ?? tp.selectedTheme,
            currentFont: extra?['currentFont'] as String? ?? tp.selectedFont,
            currentFontSize:
                extra?['currentFontSize'] as double? ?? tp.fontSize,
            theme: extra?['theme'] as ThemeData?,
          );
        },
      ),
      GoRoute(
        path: '/settings/privacy',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final tp = context.read<ThemeProvider>();
          return PrivacyPolicyScreen(
            currentTheme: extra?['currentTheme'] as String? ?? tp.selectedTheme,
            currentFont: extra?['currentFont'] as String? ?? tp.selectedFont,
            currentFontSize:
                extra?['currentFontSize'] as double? ?? tp.fontSize,
            theme: extra?['theme'] as ThemeData?,
          );
        },
      ),

      // --- カメラ・OCR ---
      GoRoute(
        path: '/camera',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return CameraScreen(
            onImageCaptured: extra?['onImageCaptured'] as void Function(File)?,
          );
        },
      ),

      // --- レシピ確認 ---
      GoRoute(
        path: '/recipe-confirm',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return RecipeConfirmScreen(
            initialIngredients:
                extra['initialIngredients'] as List<RecipeIngredient>,
            recipeTitle: extra['recipeTitle'] as String,
            sourceText: extra['sourceText'] as String,
          );
        },
      ),
    ],
  );
}
