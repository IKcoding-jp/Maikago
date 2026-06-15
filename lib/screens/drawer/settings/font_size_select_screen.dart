import 'package:flutter/material.dart';

/// フォントサイズ選択画面
class FontSizeSelectScreen extends StatefulWidget {
  const FontSizeSelectScreen({
    super.key,
    required this.currentFontSize,
    required this.theme,
    required this.onFontSizeChanged,
  });

  final double currentFontSize;
  final ThemeData theme;
  final ValueChanged<double> onFontSizeChanged;

  @override
  State<FontSizeSelectScreen> createState() => _FontSizeSelectScreenState();
}

class _FontSizeSelectScreenState extends State<FontSizeSelectScreen> {
  late double _selectedFontSize;

  @override
  void initState() {
    super.initState();
    _selectedFontSize = widget.currentFontSize;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('フォントサイズ'),
        backgroundColor: widget.theme.colorScheme.primary,
        foregroundColor: widget.theme.colorScheme.onPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // プレビューセクション
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: widget.theme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.theme.colorScheme.outline.withValues(
                    alpha: 0.2,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'プレビュー',
                    style: widget.theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'このテキストのサイズで表示されます',
                    style: widget.theme.textTheme.bodyLarge?.copyWith(
                      fontSize: _selectedFontSize,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '小さいテキストの例',
                    style: widget.theme.textTheme.bodyMedium?.copyWith(
                      fontSize: _selectedFontSize - 2,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // フォントサイズ選択
            Text(
              'フォントサイズ',
              style: widget.theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: widget.theme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.theme.colorScheme.outline.withValues(
                    alpha: 0.2,
                  ),
                ),
              ),
              child: Column(
                children: [
                  // スライダー
                  Slider(
                    value: _selectedFontSize,
                    min: 12.0,
                    max: 24.0,
                    divisions: 12,
                    label: '${_selectedFontSize.toInt()}px',
                    onChanged: (value) {
                      setState(() {
                        _selectedFontSize = value;
                      });
                      widget.onFontSizeChanged(value);
                    },
                  ),
                  const SizedBox(height: 16),

                  // プリセットボタン
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildPresetButton(14.0, '小'),
                      _buildPresetButton(16.0, '中'),
                      _buildPresetButton(18.0, '大'),
                      _buildPresetButton(20.0, '特大'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 現在のサイズ表示
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  '現在のサイズ: ${_selectedFontSize.toInt()}px',
                  style: widget.theme.textTheme.bodyMedium?.copyWith(
                    fontSize: _selectedFontSize,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetButton(double fontSize, String label) {
    final isSelected = _selectedFontSize == fontSize;
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _selectedFontSize = fontSize;
        });
        widget.onFontSizeChanged(fontSize);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected
            ? widget.theme.colorScheme.primary
            : widget.theme.cardColor,
        foregroundColor: isSelected
            ? widget.theme.colorScheme.onPrimary
            : widget.theme.colorScheme.onSurface,
        side: BorderSide(
          color: isSelected
              ? widget.theme.colorScheme.primary
              : widget.theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label, style: TextStyle(fontSize: fontSize - 2)),
    );
  }
}
