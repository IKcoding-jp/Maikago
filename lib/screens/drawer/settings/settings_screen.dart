import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:maikago/services/settings_theme.dart';
import 'package:maikago/services/settings_persistence.dart';
import 'package:maikago/screens/drawer/settings/theme_select_screen.dart';
import 'package:maikago/services/app_info_service.dart';

import 'package:maikago/screens/drawer/settings/widgets/settings_common_widgets.dart';
import 'package:maikago/screens/drawer/settings/widgets/account_card.dart';
import 'package:maikago/screens/drawer/settings/widgets/appearance_section.dart';
import 'package:maikago/screens/drawer/settings/widgets/advanced_section.dart';
import 'package:maikago/screens/drawer/settings/widgets/app_info_section.dart';

/// メインの設定画面
/// アカウント情報、テーマ、フォントなどの設定項目を管理
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.currentTheme,
    required this.currentFont,
    required this.currentFontSize,
    required this.onThemeChanged,
    required this.onFontChanged,
    required this.onFontSizeChanged,
    this.theme,
    this.onCustomThemeChanged,
    this.isDarkMode,
    this.onDarkModeChanged,
  });

  final String currentTheme;
  final String currentFont;
  final double currentFontSize;
  final ValueChanged<String> onThemeChanged;
  final ValueChanged<String> onFontChanged;
  final ValueChanged<double> onFontSizeChanged;
  final ThemeData? theme;
  final ValueChanged<Map<String, Color>>? onCustomThemeChanged;
  final bool? isDarkMode;
  final ValueChanged<bool>? onDarkModeChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late SettingsState _settingsState;
  final AppInfoService _appInfoService = AppInfoService();
  String _currentVersion = '';
  bool _isUpdateAvailable = false;
  String? _latestVersion;
  bool _isCheckingUpdate = false;

  @override
  void initState() {
    super.initState();
    _settingsState = SettingsState();
    _settingsState.setInitialState(
      theme: widget.currentTheme,
      font: widget.currentFont,
      fontSize: widget.currentFontSize,
    );
    _loadVersionInfo();
    _checkForUpdates();
  }

  Future<void> _loadVersionInfo() async {
    final version = await _appInfoService.getCurrentVersion();
    setState(() {
      _currentVersion = version;
    });
  }

  Future<void> _checkForUpdates() async {
    setState(() {
      _isCheckingUpdate = true;
    });

    try {
      final hasUpdate = await _appInfoService.checkForUpdates();
      setState(() {
        _isUpdateAvailable = hasUpdate;
        _latestVersion = _appInfoService.latestVersion;
        _isCheckingUpdate = false;
      });
    } catch (e) {
      setState(() {
        _isCheckingUpdate = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _settingsState,
      child: Consumer<SettingsState>(
        builder: (context, settingsState, _) {
          return Scaffold(
            appBar: _buildAppBar(settingsState),
            body: _buildBody(settingsState),
          );
        },
      ),
    );
  }

  /// アプリバーを構築
  PreferredSizeWidget _buildAppBar(SettingsState settingsState) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.pop(),
      ),
      title: Text(
        '設定',
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color:
                  SettingsTheme.getOnPrimaryColor(settingsState.selectedTheme),
            ),
      ),
      backgroundColor:
          SettingsTheme.getPrimaryColor(settingsState.selectedTheme),
      foregroundColor:
          SettingsTheme.getOnPrimaryColor(settingsState.selectedTheme),
      iconTheme: IconThemeData(
        color: SettingsTheme.getOnPrimaryColor(settingsState.selectedTheme),
      ),
      elevation: 0,
    );
  }

  /// ボディを構築
  Widget _buildBody(SettingsState settingsState) {
    return Container(
      color: SettingsTheme.getSurfaceColor(settingsState.selectedTheme),
      child: ListView(
        padding: EdgeInsets.only(
          left: 18,
          right: 18,
          top: 24,
          bottom: MediaQuery.of(context).padding.bottom + 24,
        ),
        children: [
          SettingsSectionHeader(
            title: '設定',
            icon: Icons.settings,
            iconColor:
                SettingsTheme.getPrimaryColor(settingsState.selectedTheme),
            textColor: SettingsTheme.getTextColor(settingsState.selectedTheme),
          ),
          AccountCard(settingsState: settingsState),
          AppearanceSection(
            settingsState: settingsState,
            onThemeTap: () => _navigateToThemeSelect(settingsState),
            onFontTap: () => _navigateToFontSelect(settingsState),
            onFontSizeTap: () => _navigateToFontSizeSelect(settingsState),
          ),
          AdvancedSection(settingsState: settingsState),
          AppInfoSection(
            settingsState: settingsState,
            currentVersion: _currentVersion,
            isUpdateAvailable: _isUpdateAvailable,
            latestVersion: _latestVersion,
            isCheckingUpdate: _isCheckingUpdate,
            onCheckForUpdates: _checkForUpdates,
            appInfoService: _appInfoService,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// テーマ選択画面に遷移
  Future<void> _navigateToThemeSelect(SettingsState settingsState) async {
    await context.push('/settings/theme', extra: {
      'currentTheme': settingsState.selectedTheme,
      'theme': _getCurrentTheme(settingsState),
      'onThemeChanged': _handleThemeChanged,
    });
    // テーマ選択画面から戻ってきた時に設定画面のテーマを更新
    setState(() {});
  }

  /// フォントサイズ選択画面に遷移
  Future<void> _navigateToFontSizeSelect(SettingsState settingsState) async {
    await context.push('/settings/font-size', extra: {
      'currentFontSize': settingsState.selectedFontSize,
      'theme': _getCurrentTheme(settingsState),
      'onFontSizeChanged': _handleFontSizeChanged,
    });
    // フォントサイズ選択画面から戻ってきた時に設定画面のテーマを更新
    setState(() {});
  }

  /// フォント選択画面に遷移
  Future<void> _navigateToFontSelect(SettingsState settingsState) async {
    await context.push('/settings/font', extra: {
      'currentFont': settingsState.selectedFont,
      'theme': _getCurrentTheme(settingsState),
      'onFontChanged': _handleFontChanged,
    });
    // フォント選択画面から戻ってきた時に設定画面のテーマを更新
    setState(() {});
  }

  /// テーマ変更を処理
  Future<void> _handleThemeChanged(String theme) async {
    _settingsState.updateTheme(theme);
    if (mounted) setState(() {});
    // 即時に親（MainScreen）へ通知し、グローバルテーマも同フレームで更新
    widget.onThemeChanged(theme);
    await SettingsPersistence.saveTheme(theme);
  }

  /// フォント変更を処理
  Future<void> _handleFontChanged(String font) async {
    _settingsState.updateFont(font);
    widget.onFontChanged(font);
    await SettingsPersistence.saveFont(font);
    // 設定画面のテーマを更新
    setState(() {});
  }

  /// フォントサイズ変更を処理
  Future<void> _handleFontSizeChanged(double fontSize) async {
    _settingsState.updateFontSize(fontSize);
    widget.onFontSizeChanged(fontSize);
    await SettingsPersistence.saveFontSize(fontSize);
    // 設定画面のテーマを更新
    setState(() {});
  }

  /// 現在のテーマを取得
  ThemeData _getCurrentTheme(SettingsState settingsState) {
    return SettingsTheme.generateTheme(
      selectedTheme: settingsState.selectedTheme,
      selectedFont: settingsState.selectedFont,
      fontSize: settingsState.selectedFontSize,
    );
  }
}
