import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import 'package:maikago/providers/auth_provider.dart';
import 'package:maikago/providers/theme_provider.dart';
import 'package:maikago/utils/dialog_utils.dart';
import 'package:maikago/widgets/welcome_dialog.dart';
import 'package:maikago/widgets/version_update_dialog.dart';
import 'package:maikago/services/version_notification_service.dart';
import 'package:maikago/services/debug_service.dart';
import 'package:maikago/models/release_history.dart';
import 'package:go_router/go_router.dart';
import 'package:maikago/services/settings_persistence.dart';

/// メイン画面の起動時ヘルパー（バージョン更新・ウェルカムダイアログ）
class StartupHelpers {
  StartupHelpers._();

  /// バージョン更新通知をチェック
  static Future<void> checkForVersionUpdate(BuildContext context) async {
    try {
      final shouldShow =
          await VersionNotificationService.shouldShowVersionNotification();
      if (shouldShow && context.mounted) {
        final latestRelease = VersionNotificationService.getLatestReleaseNote();
        if (latestRelease != null) {
          showVersionUpdateDialog(context, latestRelease);
        }
      }
    } catch (e) {
      DebugService().logError('バージョン更新チェックエラー: $e');
    }
  }

  /// バージョン更新ダイアログを表示
  static void showVersionUpdateDialog(
      BuildContext context, ReleaseNote latestRelease) {
    final tp = context.read<ThemeProvider>();
    showConstrainedDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => VersionUpdateDialog(
        latestRelease: latestRelease,
        currentTheme: tp.selectedTheme,
        currentFont: tp.selectedFont,
        currentFontSize: tp.fontSize,
        onViewDetails: () {
          context.pop();
          context.push('/release-history', extra: {
            'currentTheme': tp.selectedTheme,
            'currentFont': tp.selectedFont,
            'currentFontSize': tp.fontSize,
          });
        },
        onDismiss: () {
          context.pop();
        },
      ),
    );
  }

  /// 初回起動時にウェルカムダイアログを表示
  static Future<void> checkAndShowWelcomeDialog(
    BuildContext context, {
    GlobalKey? fabKey,
    GlobalKey? itemListKey,
    GlobalKey? addTabKey,
    GlobalKey? budgetKey,
  }) async {
    final isFirstLaunch = await SettingsPersistence.isFirstLaunch();
    if (isFirstLaunch && context.mounted) {
      unawaited(showConstrainedDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => WelcomeDialog(
          onCompleted: () {
            if (fabKey != null &&
                itemListKey != null &&
                addTabKey != null &&
                budgetKey != null) {
              _showCoachMark(
                context,
                fabKey: fabKey,
                itemListKey: itemListKey,
                addTabKey: addTabKey,
                budgetKey: budgetKey,
              );
            }
          },
        ),
      ));
    } else if (!isFirstLaunch) {
      if (fabKey != null &&
          itemListKey != null &&
          addTabKey != null &&
          budgetKey != null) {
        await _showCoachMark(
          context,
          fabKey: fabKey,
          itemListKey: itemListKey,
          addTabKey: addTabKey,
          budgetKey: budgetKey,
        );
      }
    }
  }

  static Future<void> _showCoachMark(
    BuildContext context, {
    required GlobalKey fabKey,
    required GlobalKey itemListKey,
    required GlobalKey addTabKey,
    required GlobalKey budgetKey,
  }) async {
    final isCompleted = await SettingsPersistence.isCoachMarkCompleted();
    if (isCompleted || !context.mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;

      // 認証済みまたはゲストモードでない場合はスキップ
      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (!authProvider.isLoggedIn && !authProvider.isGuestMode) return;
      } catch (_) {
        return;
      }

      final targets = <TargetFocus>[
        TargetFocus(
          identify: 'fab',
          keyTarget: fabKey,
          alignSkip: Alignment.topRight,
          shape: ShapeLightFocus.RRect,
          radius: 8,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              builder: (context, controller) => _buildTooltip(
                context,
                'ここからリストに追加できます',
                '次へ (1/4)',
                controller.next,
                controller.skip,
              ),
            ),
          ],
        ),
        TargetFocus(
          identify: 'itemList',
          keyTarget: itemListKey,
          alignSkip: Alignment.topRight,
          shape: ShapeLightFocus.RRect,
          radius: 12,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) => _buildTooltip(
                context,
                'リストを追加したら左スワイプで購入済みに移動できます',
                '次へ (2/4)',
                controller.next,
                controller.skip,
              ),
            ),
          ],
        ),
        TargetFocus(
          identify: 'addTab',
          keyTarget: addTabKey,
          alignSkip: Alignment.bottomCenter,
          shape: ShapeLightFocus.RRect,
          radius: 20,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) => _buildTooltip(
                context,
                'タブを追加して複数の買い物リストを管理できます',
                '次へ (3/4)',
                controller.next,
                controller.skip,
              ),
            ),
          ],
        ),
        TargetFocus(
          identify: 'budget',
          keyTarget: budgetKey,
          alignSkip: Alignment.topRight,
          shape: ShapeLightFocus.RRect,
          radius: 8,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              builder: (context, controller) => _buildTooltip(
                context,
                '予算を設定して買いすぎを防止しましょう',
                '始める',
                controller.next,
                controller.skip,
              ),
            ),
          ],
        ),
      ];

      TutorialCoachMark(
        targets: targets,
        colorShadow: Theme.of(context).colorScheme.shadow,
        opacityShadow: 0.7,
        hideSkip: true,
        pulseEnable: false,
        focusAnimationDuration: const Duration(milliseconds: 500),
        unFocusAnimationDuration: const Duration(milliseconds: 500),
        onFinish: () async {
          await SettingsPersistence.setCoachMarkCompleted();
        },
        onSkip: () {
          SettingsPersistence.setCoachMarkCompleted();
          return true;
        },
      ).show(context: context);
    });
  }

  static Widget _buildTooltip(
    BuildContext context,
    String description,
    String buttonText,
    VoidCallback onNext,
    VoidCallback onSkip,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(12),
        color: theme.cardColor,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      description,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: onSkip,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        'スキップ',
                        style: TextStyle(
                          color: colorScheme.outline,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Center(
                child: FilledButton(
                  onPressed: onNext,
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                  ),
                  child: Text(buttonText),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
