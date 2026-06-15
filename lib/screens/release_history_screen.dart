import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:maikago/models/release_history.dart';
import 'package:maikago/services/settings_theme.dart';
import 'package:maikago/utils/theme_utils.dart';
import 'package:go_router/go_router.dart';
import 'package:maikago/screens/release_history/widgets/timeline_entry.dart';

/// 更新履歴画面（タイムラインデザイン）
class ReleaseHistoryScreen extends StatefulWidget {
  const ReleaseHistoryScreen({
    super.key,
    required this.currentTheme,
    required this.currentFont,
    required this.currentFontSize,
  });

  final String currentTheme;
  final String currentFont;
  final double currentFontSize;

  @override
  State<ReleaseHistoryScreen> createState() => _ReleaseHistoryScreenState();
}

class _ReleaseHistoryScreenState extends State<ReleaseHistoryScreen> {
  String _currentAppVersion = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentVersion();
  }

  Future<void> _loadCurrentVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _currentAppVersion = packageInfo.version;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _currentAppVersion = '';
        _isLoading = false;
      });
    }
  }

  Color get _primaryColor => SettingsTheme.getPrimaryColor(widget.currentTheme);
  Color get _onPrimaryColor =>
      SettingsTheme.getOnPrimaryColor(widget.currentTheme);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(
          '更新履歴',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: _onPrimaryColor,
              ),
        ),
        backgroundColor: _primaryColor,
        foregroundColor: _onPrimaryColor,
        iconTheme: IconThemeData(color: _onPrimaryColor),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    final releaseNotes = ReleaseHistory.getAllReleaseNotes();

    if (releaseNotes.isEmpty) return _buildEmptyState();

    return ListView.builder(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).padding.bottom + 32,
      ),
      itemCount: releaseNotes.length,
      itemBuilder: (context, index) {
        final note = releaseNotes[index];
        final isFirst = index == 0;
        final isLast = index == releaseNotes.length - 1;
        final isCurrent = note.version == _currentAppVersion;

        return TimelineEntry(
          note: note,
          isFirst: isFirst,
          isLast: isLast,
          isCurrent: isCurrent,
          primaryColor: _primaryColor,
          onPrimaryColor: _onPrimaryColor,
        );
      },
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_rounded,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.38),
            ),
            const SizedBox(height: 16),
            Text(
              '更新履歴はまだありません',
              style: TextStyle(
                fontSize: theme.textTheme.headlineMedium?.fontSize,
                fontWeight: FontWeight.bold,
                color: theme.subtextColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '新しいバージョンがリリースされると、\nここに更新内容が表示されます。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: theme.textTheme.bodyMedium?.fontSize,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
