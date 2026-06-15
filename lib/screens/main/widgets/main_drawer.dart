import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:maikago/providers/theme_provider.dart';
import 'package:maikago/services/one_time_purchase_service.dart';
import 'package:maikago/services/settings_theme.dart';

/// メイン画面のDrawer（サイドメニュー）
class MainDrawer extends StatelessWidget {
  const MainDrawer({
    super.key,
    required this.theme,
    required this.currentTheme,
    required this.currentFont,
    required this.currentFontSize,
    required this.drawerItemColor,
    required this.drawerTextColor,
    required this.onCustomColorsChanged,
    required this.onSettingsReturned,
  });

  final ThemeData theme;
  final String currentTheme;
  final String currentFont;
  final double currentFontSize;
  final Color drawerItemColor;
  final Color? drawerTextColor;
  final void Function(Map<String, Color>) onCustomColorsChanged;
  final VoidCallback onSettingsReturned;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildMenuItem(
                    context,
                    icon: Icons.info_outline_rounded,
                    title: 'アプリについて',
                    onTap: () {
                      context.pop();
                      context.push('/about');
                    },
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.help_outline_rounded,
                    title: '使い方',
                    onTap: () {
                      context.pop();
                      context.push('/usage');
                    },
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.calculate_rounded,
                    title: '簡単電卓',
                    onTap: () {
                      context.pop();
                      context.push('/calculator', extra: {
                        'currentTheme': currentTheme,
                        'theme': theme,
                      });
                    },
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.palette_rounded,
                    title: 'まいかごプレミアム',
                    onTap: () {
                      context.pop();
                      context.push('/subscription');
                    },
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.feedback_rounded,
                    title: 'フィードバック',
                    onTap: () {
                      context.pop();
                      context.push('/feedback');
                    },
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.history_rounded,
                    title: '更新履歴',
                    onTap: () {
                      context.pop();
                      context.push('/release-history', extra: {
                        'currentTheme': currentTheme,
                        'currentFont': currentFont,
                        'currentFontSize': currentFontSize,
                      });
                    },
                  ),
                  _buildSettingsMenuItem(context),
                  if (kDebugMode) _buildDebugPremiumToggle(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return DrawerHeader(
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_basket_rounded,
            size: 48,
            color: SettingsTheme.getOnPrimaryColor(currentTheme),
          ),
          const SizedBox(height: 8),
          Text(
            'まいカゴ',
            style: TextStyle(
              fontSize: Theme.of(context).textTheme.displayMedium?.fontSize,
              color: SettingsTheme.getOnPrimaryColor(currentTheme),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: drawerItemColor),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: drawerTextColor,
        ),
      ),
      onTap: onTap,
    );
  }

  Widget _buildDebugPremiumToggle(BuildContext context) {
    return Consumer<OneTimePurchaseService>(
      builder: (context, purchaseService, _) {
        final isPremium = purchaseService.isPremiumUnlocked;
        final isOverrideActive = purchaseService.isDebugPremiumOverrideActive;
        return ListTile(
          leading: Icon(
            isPremium ? Icons.star_rounded : Icons.star_border_rounded,
            color: isPremium
                ? Theme.of(context).colorScheme.primary
                : drawerItemColor,
          ),
          title: Text(
            isPremium ? 'DEBUG: Premium ON' : 'DEBUG: Premium OFF',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: drawerTextColor,
            ),
          ),
          subtitle: isOverrideActive
              ? const Text(
                  'Override active (tap to reset)',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.statusInDevelopment,
                  ),
                )
              : null,
          onTap: () {
            if (isOverrideActive && isPremium) {
              purchaseService.debugSetPremiumOverride(false);
            } else if (isOverrideActive && !isPremium) {
              purchaseService.debugSetPremiumOverride(null);
            } else {
              purchaseService.debugSetPremiumOverride(true);
            }
          },
        );
      },
    );
  }

  Widget _buildSettingsMenuItem(BuildContext context) {
    return ListTile(
      leading: Icon(Icons.settings_rounded, color: drawerItemColor),
      title: Text(
        '設定',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: drawerTextColor,
        ),
      ),
      onTap: () async {
        context.pop();
        final tp = context.read<ThemeProvider>();
        await context.push<void>('/settings', extra: {
          'onThemeChanged': (String themeKey) {
            tp.updateTheme(themeKey);
          },
          'onFontChanged': (String font) {
            tp.updateFont(font);
          },
          'onFontSizeChanged': (double fontSize) {
            tp.updateFontSize(fontSize);
          },
          'onCustomThemeChanged': onCustomColorsChanged,
          'onDarkModeChanged': (bool isDark) {},
        });
        onSettingsReturned();
      },
    );
  }
}
