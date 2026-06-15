import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:maikago/services/settings_theme.dart';
import 'package:maikago/screens/drawer/settings/theme_select_screen.dart';
import 'package:maikago/providers/auth_provider.dart';
import 'package:maikago/screens/drawer/settings/widgets/settings_common_widgets.dart';

/// アカウント情報カードウィジェット
class AccountCard extends StatelessWidget {
  const AccountCard({
    super.key,
    required this.settingsState,
  });

  final SettingsState settingsState;

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        return SettingsCard(
          backgroundColor:
              SettingsTheme.getCardColor(settingsState.selectedTheme),
          child: SettingsListItem(
            title: 'アカウント情報',
            subtitle: authProvider.isLoggedIn ? 'ログイン済み' : 'Googleアカウントでログイン',
            leadingIcon: Icons.account_circle_rounded,
            backgroundColor:
                SettingsTheme.getPrimaryColor(settingsState.selectedTheme),
            textColor: SettingsTheme.getTextColor(settingsState.selectedTheme),
            iconColor:
                SettingsTheme.getOnPrimaryColor(settingsState.selectedTheme),
            onTap: () {
              context.push('/settings/account');
            },
            trailing: CircleAvatar(
              backgroundImage: authProvider.userPhotoURL != null
                  ? NetworkImage(authProvider.userPhotoURL!)
                  : null,
              backgroundColor:
                  SettingsTheme.getPrimaryColor(settingsState.selectedTheme),
              child: authProvider.userPhotoURL == null
                  ? Icon(
                      Icons.account_circle_rounded,
                      color: SettingsTheme.getOnPrimaryColor(
                        settingsState.selectedTheme,
                      ),
                    )
                  : null,
            ),
          ),
        );
      },
    );
  }
}
