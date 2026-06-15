import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:maikago/screens/drawer/widgets/calculator/calculator_button.dart';
import 'package:maikago/screens/drawer/widgets/calculator/calculator_display.dart';
import 'package:maikago/screens/drawer/widgets/calculator/calculator_hint_dialog.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({
    super.key,
    required this.currentTheme,
    required this.theme,
  });

  final String currentTheme;
  final ThemeData theme;

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen>
    with TickerProviderStateMixin {
  double totalAmount = 0.0;
  String _currentInput = '';
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _addToInput(String value) {
    setState(() {
      _currentInput += value;
    });
    HapticFeedback.lightImpact();
  }

  void _addAmount() {
    if (_currentInput.isNotEmpty) {
      final amount = double.tryParse(_currentInput);
      if (amount != null && amount > 0) {
        setState(() {
          totalAmount += amount;
          _currentInput = '';
        });

        // 追加時のアニメーション
        _animationController.forward().then((_) {
          _animationController.reverse();
        });

        // ハプティックフィードバック
        HapticFeedback.lightImpact();
      }
    }
  }

  void _clearAll() {
    setState(() {
      totalAmount = 0.0;
      _currentInput = '';
    });
    HapticFeedback.mediumImpact();
  }

  void _deleteLastDigit() {
    if (_currentInput.isNotEmpty) {
      setState(() {
        _currentInput = _currentInput.substring(0, _currentInput.length - 1);
      });
      HapticFeedback.lightImpact();
    }
  }

  Color _getIconColor() {
    return widget.theme.colorScheme.onPrimary;
  }

  Color _getTotalAmountColor() {
    return widget.theme.colorScheme.primary;
  }

  Color? _getTextColor() {
    return widget.theme.colorScheme.onSurface;
  }

  Color _getBackgroundColor() {
    return widget.theme.colorScheme.primary;
  }

  Color _getCardColor() {
    return widget.theme.cardColor;
  }

  Color _getButtonColor() {
    return widget.theme.cardColor;
  }

  bool get _isDark => widget.theme.brightness == Brightness.dark;

  Color get _outlineColor =>
      widget.theme.colorScheme.outline.withValues(alpha: 0.2);

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 700;

    // レスポンシブ間隔の定数
    final gapLarge = isSmallScreen ? 16.0 : 24.0;
    final paddingMedium = isSmallScreen ? 12.0 : 16.0;
    final paddingLarge = isSmallScreen ? 12.0 : 20.0;

    return Scaffold(
      backgroundColor: _getBackgroundColor(),
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.calculate_rounded, color: _getIconColor()),
            const SizedBox(width: 8),
            Text(
              '簡単電卓',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _getIconColor(),
              ),
            ),
          ],
        ),
        backgroundColor: _getBackgroundColor(),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: _getIconColor()),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline_rounded, color: _getIconColor()),
            onPressed: () => showCalculatorHintDialog(context, widget.theme),
            tooltip: '使い方を見る',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: paddingMedium,
            vertical: paddingLarge,
          ),
          child: Column(
            children: [
              // 合計表示エリア
              CalculatorTotalDisplay(
                theme: widget.theme,
                totalAmount: totalAmount,
                scaleAnimation: _scaleAnimation,
                isSmallScreen: isSmallScreen,
                totalAmountColor: _getTotalAmountColor(),
                textColor: _getTextColor(),
                cardColor: _getCardColor(),
              ),
              SizedBox(height: gapLarge),

              // 入力表示エリア
              CalculatorInputDisplay(
                theme: widget.theme,
                currentInput: _currentInput,
                isSmallScreen: isSmallScreen,
                textColor: _getTextColor(),
                cardColor: _getCardColor(),
              ),
              SizedBox(height: gapLarge),

              // 電卓ボタンエリア
              Expanded(
                child: _buildButtonPad(isSmallScreen),
              ),
              SizedBox(height: paddingLarge), // 下部マージンを追加
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildButtonPad(bool isSmallScreen) {
    // レスポンシブ間隔の定数
    final gapSmall = isSmallScreen ? 6.0 : 8.0;
    final gapMedium = isSmallScreen ? 12.0 : 16.0;
    final paddingMedium = isSmallScreen ? 12.0 : 16.0;

    return Container(
      padding: EdgeInsets.all(paddingMedium),
      decoration: BoxDecoration(
        color: _getCardColor(),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: widget.theme.shadowColor.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 数字ボタン
          Expanded(
            child: Column(
              children: [
                _buildNumberRow(['7', '8', '9'], isSmallScreen),
                SizedBox(height: gapSmall),
                _buildNumberRow(['4', '5', '6'], isSmallScreen),
                SizedBox(height: gapSmall),
                _buildNumberRow(['1', '2', '3'], isSmallScreen),
                SizedBox(height: gapSmall),
                // 4行目: 0, 00, 削除
                Expanded(
                  child: Row(
                    children: [
                      _buildNumBtn('0', isSmallScreen),
                      SizedBox(width: gapSmall),
                      _buildNumBtn('00', isSmallScreen),
                      SizedBox(width: gapSmall),
                      CalculatorActionButton(
                        icon: Icons.backspace_rounded,
                        onPressed: _deleteLastDigit,
                        color: widget.theme.colorScheme.error,
                        isSmallScreen: isSmallScreen,
                        buttonColor: _getButtonColor(),
                        onPrimaryColor: widget.theme.colorScheme.onPrimary,
                        isDark: _isDark,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: gapMedium),
          // アクションボタン
          Row(
            children: [
              Expanded(
                child: CalculatorActionButton(
                  icon: Icons.clear_all_rounded,
                  label: 'クリア',
                  onPressed: _clearAll,
                  color: widget.theme.colorScheme.error,
                  isSmallScreen: isSmallScreen,
                  buttonColor: _getButtonColor(),
                  onPrimaryColor: widget.theme.colorScheme.onPrimary,
                  isDark: _isDark,
                ),
              ),
              SizedBox(width: isSmallScreen ? 8 : 12),
              Expanded(
                child: CalculatorActionButton(
                  icon: Icons.add_rounded,
                  label: '追加',
                  onPressed: _addAmount,
                  color: widget.theme.colorScheme.primary,
                  isPrimary: true,
                  isSmallScreen: isSmallScreen,
                  buttonColor: _getButtonColor(),
                  onPrimaryColor: widget.theme.colorScheme.onPrimary,
                  isDark: _isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNumberRow(List<String> numbers, bool isSmallScreen) {
    final gapSmall = isSmallScreen ? 6.0 : 8.0;
    return Expanded(
      child: Row(
        children: [
          for (int i = 0; i < numbers.length; i++) ...[
            if (i > 0) SizedBox(width: gapSmall),
            _buildNumBtn(numbers[i], isSmallScreen),
          ],
        ],
      ),
    );
  }

  CalculatorNumberButton _buildNumBtn(String number, bool isSmallScreen) {
    return CalculatorNumberButton(
      number: number,
      isSmallScreen: isSmallScreen,
      onPressed: () => _addToInput(number),
      buttonColor: _getButtonColor(),
      textColor: _getTextColor(),
      outlineColor: _outlineColor,
      isDark: _isDark,
    );
  }
}
