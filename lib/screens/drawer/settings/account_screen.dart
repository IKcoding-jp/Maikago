import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:maikago/providers/auth_provider.dart';
import 'package:maikago/providers/data_provider.dart';
import 'package:maikago/widgets/common_dialog.dart';
import 'package:maikago/utils/snackbar_utils.dart';
import 'package:maikago/services/settings_theme.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('アカウント管理'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          if (authProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (authProvider.isLoggedIn) {
            return _buildUserProfile(context, authProvider);
          } else {
            return _buildLoginSection(context);
          }
        },
      ),
    );
  }

  Widget _buildLoginSection(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.only(
          left: 24.0,
          right: 24.0,
          top: 24.0,
          bottom: MediaQuery.of(context).padding.bottom + 24.0,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(
                Icons.account_circle_rounded,
                size: 64,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Googleアカウントでログイン',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ログインすると、お買い物リストが\nクラウドに自動保存されます',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.70),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.login),
                label: const Text('Googleでログイン'),
                onPressed: () => _handleGoogleSignIn(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserProfile(BuildContext context, AuthProvider authProvider) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 24.0,
        right: 24.0,
        top: 24.0,
        bottom: MediaQuery.of(context).padding.bottom + 24.0,
      ),
      child: Column(
        children: [
          // ユーザー情報セクション
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.shadow.withValues(alpha: 0.10),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundImage: authProvider.userPhotoURL != null
                      ? NetworkImage(authProvider.userPhotoURL!)
                      : null,
                  backgroundColor: theme.colorScheme.primary,
                  child: authProvider.userPhotoURL == null
                      ? Icon(
                          Icons.account_circle_rounded,
                          size: 80,
                          color: theme.colorScheme.onPrimary,
                        )
                      : null,
                ),
                const SizedBox(height: 16),
                Text(
                  authProvider.userDisplayName ?? 'ユーザー',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  authProvider.userEmail ?? '',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.70),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 同期状態セクション
          Consumer<DataProvider>(
            builder: (context, dataProvider, _) {
              final isSynced = dataProvider.isSynced;
              final statusColor =
                  isSynced ? AppColors.success : AppColors.warning;

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.30),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSynced ? Icons.cloud_done : Icons.cloud_off,
                      color: statusColor,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isSynced ? 'クラウド同期済み' : 'クラウド未同期',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            isSynced ? 'データは安全に保存されています' : 'ログインしてデータを同期してください',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.70),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const Spacer(),

          // ログアウトボタン
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text('ログアウト'),
              onPressed: () => _handleLogout(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleGoogleSignIn(BuildContext context) async {
    try {
      final authProvider = context.read<AuthProvider>();
      final result = await authProvider.signInWithGoogle();
      if (result == 'success' && context.mounted) {
        // ゲストデータの移行結果を確認し、一部失敗していれば通知（Issue #154）。
        final migration = authProvider.consumeLastMigrationResult();
        // ログイン成功時にデータを読み込み
        await context.read<DataProvider>().loadData();
        if (context.mounted) {
          if (migration != null && migration.hasFailures) {
            showWarningSnackBar(
              context,
              'お買い物リストの一部をクラウドに保存できませんでした。'
              'データは端末に残っており、次回アプリ起動時に自動で再試行します。',
              duration: const Duration(seconds: 6),
            );
          } else {
            showSuccessSnackBar(context, 'ログインしました');
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        showErrorSnackBar(context, 'ログインエラー: $e');
      }
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await CommonDialog.show<bool>(
      context: context,
      builder: (context) => CommonDialog(
        title: 'ログアウト',
        content: const Text('ログアウトしますか？\nローカルデータは保持されます。'),
        actions: [
          CommonDialog.cancelButton(context,
              onPressed: () => context.pop(false)),
          CommonDialog.destructiveButton(context,
              label: 'ログアウト', onPressed: () => context.pop(true)),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        // データをクリア
        context.read<DataProvider>().clearData();
        // ログアウト
        await context.read<AuthProvider>().signOut();

        if (context.mounted) {
          showInfoSnackBar(context, 'ログアウトしました');
        }
      } catch (e) {
        if (context.mounted) {
          showErrorSnackBar(context, 'ログアウトエラー: $e');
        }
      }
    }
  }
}
