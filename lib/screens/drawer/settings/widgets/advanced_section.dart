import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:maikago/services/settings_theme.dart';
import 'package:maikago/screens/drawer/settings/theme_select_screen.dart';
import 'package:maikago/screens/drawer/settings/widgets/settings_common_widgets.dart';

/// その他セクション（詳細設定）
class AdvancedSection extends StatelessWidget {
  const AdvancedSection({
    super.key,
    required this.settingsState,
  });

  final SettingsState settingsState;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        SettingsSectionTitle(
          title: 'その他',
          textColor: SettingsTheme.getTextColor(settingsState.selectedTheme),
        ),
        _AdvancedSettingsCard(settingsState: settingsState),
      ],
    );
  }
}

/// 詳細設定カード
class _AdvancedSettingsCard extends StatelessWidget {
  const _AdvancedSettingsCard({
    required this.settingsState,
  });

  final SettingsState settingsState;

  ThemeData _getCurrentTheme() {
    return SettingsTheme.generateTheme(
      selectedTheme: settingsState.selectedTheme,
      selectedFont: settingsState.selectedFont,
      fontSize: settingsState.selectedFontSize,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      backgroundColor: SettingsTheme.getCardColor(settingsState.selectedTheme),
      child: SettingsListItem(
        title: '詳細設定',
        subtitle: 'アプリの詳細な設定',
        leadingIcon: Icons.settings_applications,
        backgroundColor:
            SettingsTheme.getPrimaryColor(settingsState.selectedTheme),
        textColor: SettingsTheme.getTextColor(settingsState.selectedTheme),
        iconColor: SettingsTheme.getOnPrimaryColor(settingsState.selectedTheme),
        onTap: () {
          context.push('/settings/advanced', extra: {
            'currentTheme': settingsState.selectedTheme,
            'currentFont': settingsState.selectedFont,
            'currentFontSize': settingsState.selectedFontSize,
            'theme': _getCurrentTheme(),
          });
        },
      ),
    );
  }
}
