import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:maikago/services/settings_theme.dart';
import 'package:maikago/screens/drawer/settings/theme_select_screen.dart';
import 'package:maikago/services/app_info_service.dart';
import 'package:maikago/screens/drawer/settings/widgets/settings_common_widgets.dart';

/// アプリ情報セクション（バージョン、更新、利用規約、プライバシー）
class AppInfoSection extends StatelessWidget {
  const AppInfoSection({
    super.key,
    required this.settingsState,
    required this.currentVersion,
    required this.isUpdateAvailable,
    required this.latestVersion,
    required this.isCheckingUpdate,
    required this.onCheckForUpdates,
    required this.appInfoService,
  });

  final SettingsState settingsState;
  final String currentVersion;
  final bool isUpdateAvailable;
  final String? latestVersion;
  final bool isCheckingUpdate;
  final VoidCallback onCheckForUpdates;
  final AppInfoService appInfoService;

  ThemeData _getCurrentTheme() {
    return SettingsTheme.generateTheme(
      selectedTheme: settingsState.selectedTheme,
      selectedFont: settingsState.selectedFont,
      fontSize: settingsState.selectedFontSize,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsSectionTitle(
          title: 'アプリ情報',
          textColor: SettingsTheme.getTextColor(settingsState.selectedTheme),
        ),
        _VersionCard(
          settingsState: settingsState,
          currentVersion: currentVersion,
          isUpdateAvailable: isUpdateAvailable,
          isCheckingUpdate: isCheckingUpdate,
          onCheckForUpdates: onCheckForUpdates,
        ),
        if (isUpdateAvailable)
          _UpdateAvailableCard(
            settingsState: settingsState,
            currentVersion: currentVersion,
            latestVersion: latestVersion,
            appInfoService: appInfoService,
          ),
        _TermsCard(
          settingsState: settingsState,
          getCurrentTheme: _getCurrentTheme,
        ),
        _PrivacyCard(
          settingsState: settingsState,
          getCurrentTheme: _getCurrentTheme,
        ),
      ],
    );
  }
}

/// バージョン情報カード
class _VersionCard extends StatelessWidget {
  const _VersionCard({
    required this.settingsState,
    required this.currentVersion,
    required this.isUpdateAvailable,
    required this.isCheckingUpdate,
    required this.onCheckForUpdates,
  });

  final SettingsState settingsState;
  final String currentVersion;
  final bool isUpdateAvailable;
  final bool isCheckingUpdate;
  final VoidCallback onCheckForUpdates;

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      backgroundColor: SettingsTheme.getCardColor(settingsState.selectedTheme),
      child: Column(
        children: [
          SettingsListItem(
            title: 'バージョン',
            subtitle: 'Version $currentVersion',
            leadingIcon: Icons.info_outline_rounded,
            backgroundColor:
                SettingsTheme.getPrimaryColor(settingsState.selectedTheme),
            textColor: SettingsTheme.getTextColor(settingsState.selectedTheme),
            iconColor:
                SettingsTheme.getOnPrimaryColor(settingsState.selectedTheme),
            onTap: onCheckForUpdates,
          ),
          if (isUpdateAvailable || isCheckingUpdate)
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (isCheckingUpdate) ...[
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '更新をチェック中...',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: SettingsTheme.getSubtextColor(
                                settingsState.selectedTheme),
                          ),
                    ),
                  ] else ...[
                    Icon(
                      Icons.system_update_rounded,
                      color: Theme.of(context).colorScheme.tertiary,
                      size: 16,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '新しいバージョンが利用可能です',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.tertiary,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 更新利用可能カード
class _UpdateAvailableCard extends StatelessWidget {
  const _UpdateAvailableCard({
    required this.settingsState,
    required this.currentVersion,
    required this.latestVersion,
    required this.appInfoService,
  });

  final SettingsState settingsState;
  final String currentVersion;
  final String? latestVersion;
  final AppInfoService appInfoService;

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      backgroundColor:
          Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.1),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.system_update_rounded,
                  color: Theme.of(context).colorScheme.tertiary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '更新情報',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: SettingsTheme.getTextColor(
                            settingsState.selectedTheme),
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '現在のバージョン: $currentVersion\n'
              '最新バージョン: $latestVersion',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: SettingsTheme.getSubtextColor(
                        settingsState.selectedTheme),
                  ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => appInfoService.openAppStore(),
              icon: const Icon(Icons.store_rounded, size: 16),
              label: const Text('アプリストアで更新'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.tertiary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 利用規約カード
class _TermsCard extends StatelessWidget {
  const _TermsCard({
    required this.settingsState,
    required this.getCurrentTheme,
  });

  final SettingsState settingsState;
  final ThemeData Function() getCurrentTheme;

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      backgroundColor: SettingsTheme.getCardColor(settingsState.selectedTheme),
      child: SettingsListItem(
        title: '利用規約',
        subtitle: 'アプリの利用に関する規約',
        leadingIcon: Icons.description_rounded,
        backgroundColor:
            SettingsTheme.getPrimaryColor(settingsState.selectedTheme),
        textColor: SettingsTheme.getTextColor(settingsState.selectedTheme),
        iconColor: SettingsTheme.getOnPrimaryColor(settingsState.selectedTheme),
        onTap: () {
          context.push('/settings/terms', extra: {
            'currentTheme': settingsState.selectedTheme,
            'currentFont': settingsState.selectedFont,
            'currentFontSize': settingsState.selectedFontSize,
            'theme': getCurrentTheme(),
          });
        },
      ),
    );
  }
}

/// プライバシーポリシーカード
class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard({
    required this.settingsState,
    required this.getCurrentTheme,
  });

  final SettingsState settingsState;
  final ThemeData Function() getCurrentTheme;

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      backgroundColor: SettingsTheme.getCardColor(settingsState.selectedTheme),
      child: SettingsListItem(
        title: 'プライバシーポリシー',
        subtitle: '個人情報の取り扱い',
        leadingIcon: Icons.privacy_tip_rounded,
        backgroundColor:
            SettingsTheme.getPrimaryColor(settingsState.selectedTheme),
        textColor: SettingsTheme.getTextColor(settingsState.selectedTheme),
        iconColor: SettingsTheme.getOnPrimaryColor(settingsState.selectedTheme),
        onTap: () {
          context.push('/settings/privacy', extra: {
            'currentTheme': settingsState.selectedTheme,
            'currentFont': settingsState.selectedFont,
            'currentFontSize': settingsState.selectedFontSize,
            'theme': getCurrentTheme(),
          });
        },
      ),
    );
  }
}
