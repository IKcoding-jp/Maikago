// Google ログインのUIとハンドリングを提供
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:maikago/providers/auth_provider.dart';
import 'package:maikago/services/debug_service.dart';
import 'package:maikago/widgets/common_dialog.dart';
import 'package:maikago/utils/snackbar_utils.dart';
import 'package:maikago/utils/theme_utils.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onLoginSuccess});

  final VoidCallback onLoginSuccess;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  /// Googleでのサインイン処理。成功時に `onLoginSuccess` をコール。
  Future<void> _signInWithGoogle() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final userCredential = await authProvider.signInWithGoogle();

      if (!mounted) return;

      if (userCredential == 'success') {
        // ゲストデータの移行結果を確認し、一部失敗していれば通知（Issue #154）。
        // データは端末に残り、次回ログイン時に自動再試行される。
        final migration = authProvider.consumeLastMigrationResult();
        if (migration != null && migration.hasFailures) {
          showWarningSnackBar(
            context,
            'お買い物リストの一部をクラウドに保存できませんでした。'
            'データは端末に残っており、次回アプリ起動時に自動で再試行します。',
            duration: const Duration(seconds: 6),
          );
        }
        widget.onLoginSuccess();
      } else if (userCredential == 'redirect') {
        // リダイレクト方式を使用（iOS PWA）
        // ページがリロードされるため、ローディング状態を維持
        return;
      } else if (userCredential == 'sign_in_canceled') {
        // ユーザーがサインインをキャンセルした場合
        if (mounted) {
          showWarningSnackBar(context, 'ログインがキャンセルされました');
        }
      } else if (userCredential != null) {
        // その他のエラーコード（network_error, sign_in_failed等）
        if (mounted) {
          showErrorSnackBar(context, 'ログインエラーが発生しました');
        }
      }
    } catch (e) {
      if (!mounted) return;

      DebugService().logError('ログインエラー: $e (${e.runtimeType})');

      String errorMessage = 'ログインエラーが発生しました';
      String detailedError = '';

      if (e.toString().contains('network_error')) {
        errorMessage = 'ネットワークエラーです。インターネット接続を確認してください。';
        detailedError = 'ネットワーク接続に問題があります。';
      } else if (e.toString().contains('sign_in_canceled')) {
        errorMessage = 'ログインがキャンセルされました';
        detailedError = 'ユーザーがログインをキャンセルしました。';
      } else if (e.toString().contains('sign_in_failed')) {
        errorMessage = 'ログインに失敗しました。設定を確認してください。';
        detailedError =
            'Google Sign-Inの設定に問題があります。\n\n確認事項:\n1. Firebase ConsoleでGoogle認証が有効か\n2. Google Cloud ConsoleでOAuth 2.0クライアントIDが正しく設定されているか\n3. SHA-1証明書フィンガープリントが正しいか\n4. パッケージ名が一致しているか\n5. OAuth同意画面でテストユーザーが追加されているか';
      } else if (e.toString().contains('invalid_account')) {
        errorMessage = '無効なアカウントです。別のGoogleアカウントをお試しください。';
        detailedError = '使用しているGoogleアカウントが無効です。';
      } else if (e.toString().contains('permission_denied')) {
        errorMessage = '権限が拒否されました。Googleアカウントの設定を確認してください。';
        detailedError = 'Googleアカウントの権限設定に問題があります。';
      } else if (e.toString().contains('ID Tokenが取得できませんでした')) {
        errorMessage = '認証トークンの取得に失敗しました。OAuth同意画面の設定を確認してください。';
        detailedError =
            'OAuth同意画面の設定に問題があります。\n\n確認事項:\n1. Google Cloud Console > OAuth同意画面でテストユーザーが追加されているか\n2. アプリの状態が適切に設定されているか';
      } else {
        detailedError = '予期しないエラーが発生しました。\n\nエラー詳細: $e';
      }

      showErrorSnackBar(context, errorMessage,
          duration: const Duration(seconds: 5));

      // 詳細エラー情報をダイアログで表示
      if (mounted) {
        unawaited(CommonDialog.show(
          context: context,
          builder: (context) => CommonDialog(
            title: 'エラー詳細',
            content: SingleChildScrollView(child: Text(detailedError)),
            actions: [
              CommonDialog.closeButton(context),
            ],
          ),
        ));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.primary.withValues(alpha: 0.10),
              colorScheme.secondary.withValues(alpha: 0.10),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // アプリロゴ・アイコン
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(60),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withValues(alpha: 0.30),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.shopping_basket_rounded,
                      size: 60,
                      color: colorScheme.onPrimary,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // アプリタイトル
                  Text(
                    'まいカゴ',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),

                  const SizedBox(height: 8),

                  // サブタイトル
                  Text(
                    'お買い物リストをクラウドで管理',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).subtextColor,
                        ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 60),

                  // ログインボタン
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _signInWithGoogle,
                      icon: _isLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  colorScheme.onPrimary,
                                ),
                              ),
                            )
                          : Icon(
                              Icons.login,
                              color: colorScheme.onPrimary,
                              size: 24,
                            ),
                      label: Text(
                        _isLoading ? 'ログイン中...' : 'Googleアカウントでログイン',
                        style: TextStyle(
                          fontSize:
                              Theme.of(context).textTheme.bodyLarge?.fontSize,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onPrimary,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        elevation: 4,
                        shadowColor:
                            colorScheme.primary.withValues(alpha: 0.30),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ゲストモードボタン
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              context.read<AuthProvider>().enterGuestMode();
                              context.go('/home');
                            },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: colorScheme.surface,
                        foregroundColor: colorScheme.onSurface,
                        side: BorderSide(
                          color: colorScheme.outline.withValues(alpha: 0.3),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'ログインせずに使う',
                        style: TextStyle(
                          fontSize:
                              Theme.of(context).textTheme.bodyLarge?.fontSize,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 説明テキスト
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.surface.withValues(alpha: 0.80),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colorScheme.secondary.withValues(alpha: 0.30),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.cloud_sync,
                          color: colorScheme.secondary,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'ログインすると、お買い物リストが\nクラウドに自動保存されます',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                  color: colorScheme.onSurface
                                      .withValues(alpha: 0.7)),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
