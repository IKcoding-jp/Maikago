import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:maikago/services/one_time_purchase_service.dart';
import 'package:maikago/utils/theme_utils.dart';
import 'package:maikago/widgets/common_dialog.dart';
import 'package:maikago/screens/drawer/settings/settings_font.dart';

/// フォント選択画面のウィジェット
/// フォントの選択とプレビュー機能
class FontSelectScreen extends StatefulWidget {
  const FontSelectScreen({
    super.key,
    required this.currentFont,
    this.theme,
    required this.onFontChanged,
  });

  final String currentFont;
  final ThemeData? theme;
  final ValueChanged<String> onFontChanged;

  @override
  State<FontSelectScreen> createState() => _FontSelectScreenState();
}

class _FontSelectScreenState extends State<FontSelectScreen>
    with TickerProviderStateMixin {
  late String selectedFont;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late final List<Map<String, dynamic>> _availableFonts;

  @override
  void initState() {
    super.initState();
    selectedFont = widget.currentFont;
    _availableFonts = FontSettings.getAvailableFonts();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = widget.theme ?? Theme.of(context);
    return Theme(
      data: baseTheme,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'フォントを選択',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          iconTheme: IconThemeData(
            color: Theme.of(context).colorScheme.onPrimary,
          ),
          elevation: 0,
          centerTitle: true,
        ),
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                Expanded(child: _buildFontContent()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ヘッダー部分を構築
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.20),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).cardShadowColor,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.font_download_rounded,
            size: 32,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'お好みのフォントを選んでください',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '選択したフォントがアプリ全体に適用されます',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.70),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// フォントコンテンツを構築
  Widget _buildFontContent() {
    return SingleChildScrollView(child: Column(children: [_buildFontGrid()]));
  }

  /// フォント選択グリッドを構築
  Widget _buildFontGrid() {
    final fonts = _availableFonts;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: fonts.length,
      itemBuilder: (context, index) {
        final font = fonts[index];
        final isSelected = selectedFont == font['key'];
        final isLocked =
            !context.read<OneTimePurchaseService>().isPremiumUnlocked &&
                font['key'] != 'nunito';

        return _buildFontItem(
          context: context,
          font: font,
          isSelected: isSelected,
          isLocked: isLocked,
          backgroundColor: Theme.of(context).cardColor,
          textColor: Theme.of(context).colorScheme.onSurface,
          primaryColor: Theme.of(context).colorScheme.primary,
          onTap: () {
            // 選択時に制限をチェック
            if (isLocked) {
              _showPremiumRequiredDialog();
            } else {
              setState(() {
                selectedFont = font['key'] as String;
              });
              widget.onFontChanged(font['key'] as String);
            }
          },
        );
      },
    );
  }

  /// プレミアムプランが必要なダイアログを表示
  void _showPremiumRequiredDialog() {
    CommonDialog.show(
      context: context,
      builder: (context) => CommonDialog(
        title: 'プレミアムプランが必要です',
        content: const Text('フォントカスタマイズ機能はプレミアムプラン以上で利用できます。'),
        actions: [
          CommonDialog.cancelButton(context),
          CommonDialog.primaryButton(context, label: 'プランを確認', onPressed: () {
            context.pop();
            context.push('/subscription');
          }),
        ],
      ),
    );
  }

  /// フォント選択アイテムを作成
  Widget _buildFontItem({
    required BuildContext context,
    required Map<String, dynamic> font,
    required bool isSelected,
    required Color backgroundColor,
    required Color textColor,
    required Color primaryColor,
    required VoidCallback onTap,
    bool isLocked = false,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color:
            isSelected ? primaryColor.withValues(alpha: 0.10) : backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? primaryColor
              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.31),
          width: isSelected ? 2.5 : 1.5,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ]
            : [
                BoxShadow(
                  color: Theme.of(context).cardShadowColor,
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  font['label'] as String,
                  style: (font['style'] as TextStyle).copyWith(
                    fontSize:
                        Theme.of(context).textTheme.titleMedium?.fontSize ?? 16,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check,
                            size: 12,
                            color: Theme.of(context).colorScheme.onPrimary),
                        const SizedBox(width: 2),
                        Text(
                          '選択中',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (isLocked)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outline,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock,
                            size: 12,
                            color: Theme.of(context).colorScheme.onPrimary),
                        const SizedBox(width: 2),
                        Text(
                          '制限中',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
