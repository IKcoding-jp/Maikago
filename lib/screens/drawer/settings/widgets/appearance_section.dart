import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:maikago/services/settings_theme.dart';
import 'package:maikago/screens/drawer/settings/theme_select_screen.dart';
import 'package:maikago/screens/drawer/settings/settings_font.dart';
import 'package:maikago/services/one_time_purchase_service.dart';
import 'package:maikago/screens/drawer/settings/widgets/settings_common_widgets.dart';

/// 外観セクション（テーマ、フォント、フォントサイズ）
class AppearanceSection extends StatelessWidget {
  const AppearanceSection({
    super.key,
    required this.settingsState,
    required this.onThemeTap,
    required this.onFontTap,
    required this.onFontSizeTap,
  });

  final SettingsState settingsState;
  final VoidCallback onThemeTap;
  final VoidCallback onFontTap;
  final VoidCallback onFontSizeTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsSectionTitle(
          title: '外観',
          textColor: SettingsTheme.getTextColor(settingsState.selectedTheme),
        ),
        _ThemeCard(settingsState: settingsState, onTap: onThemeTap),
        _FontCard(settingsState: settingsState, onTap: onFontTap),
        _FontSizeCard(settingsState: settingsState, onTap: onFontSizeTap),
      ],
    );
  }
}

/// テーマカード
class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.settingsState,
    required this.onTap,
  });

  final SettingsState settingsState;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Consumer<OneTimePurchaseService>(
      builder: (context, purchaseService, child) {
        final isLocked = !purchaseService.isPremiumUnlocked;

        return SettingsCard(
          backgroundColor:
              SettingsTheme.getCardColor(settingsState.selectedTheme),
          child: SettingsListItem(
            title: 'テーマ',
            subtitle: isLocked
                ? 'デフォルトテーマのみ'
                : SettingsTheme.getThemeLabel(settingsState.selectedTheme),
            leadingIcon: Icons.color_lens_rounded,
            backgroundColor:
                SettingsTheme.getPrimaryColor(settingsState.selectedTheme),
            textColor: SettingsTheme.getTextColor(settingsState.selectedTheme),
            iconColor:
                SettingsTheme.getOnPrimaryColor(settingsState.selectedTheme),
            onTap: onTap,
          ),
        );
      },
    );
  }
}

/// フォントカード
class _FontCard extends StatelessWidget {
  const _FontCard({
    required this.settingsState,
    required this.onTap,
  });

  final SettingsState settingsState;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Consumer<OneTimePurchaseService>(
      builder: (context, purchaseService, child) {
        final isLocked = !purchaseService.isPremiumUnlocked;

        return SettingsCard(
          backgroundColor:
              SettingsTheme.getCardColor(settingsState.selectedTheme),
          child: SettingsListItem(
            title: 'フォント',
            subtitle: isLocked
                ? 'デフォルトフォントのみ'
                : FontSettings.getFontLabel(settingsState.selectedFont),
            leadingIcon: Icons.font_download_rounded,
            backgroundColor:
                SettingsTheme.getPrimaryColor(settingsState.selectedTheme),
            textColor: SettingsTheme.getTextColor(settingsState.selectedTheme),
            iconColor:
                SettingsTheme.getOnPrimaryColor(settingsState.selectedTheme),
            onTap: onTap,
          ),
        );
      },
    );
  }
}

/// フォントサイズカード
class _FontSizeCard extends StatelessWidget {
  const _FontSizeCard({
    required this.settingsState,
    required this.onTap,
  });

  final SettingsState settingsState;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      backgroundColor: SettingsTheme.getCardColor(settingsState.selectedTheme),
      child: SettingsListItem(
        title: 'フォントサイズ',
        subtitle: '${settingsState.selectedFontSize.toInt()}px',
        leadingIcon: Icons.text_fields_rounded,
        backgroundColor:
            SettingsTheme.getPrimaryColor(settingsState.selectedTheme),
        textColor: SettingsTheme.getTextColor(settingsState.selectedTheme),
        iconColor: SettingsTheme.getOnPrimaryColor(settingsState.selectedTheme),
        onTap: onTap,
      ),
    );
  }
}
