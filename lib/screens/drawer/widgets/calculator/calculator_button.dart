import 'package:flutter/material.dart';

/// 数字ボタンウィジェット
class CalculatorNumberButton extends StatelessWidget {
  const CalculatorNumberButton({
    super.key,
    required this.number,
    required this.isSmallScreen,
    required this.onPressed,
    required this.buttonColor,
    required this.textColor,
    required this.outlineColor,
    required this.isDark,
  });

  final String number;
  final bool isSmallScreen;
  final VoidCallback onPressed;
  final Color buttonColor;
  final Color? textColor;
  final Color outlineColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SizedBox(
        height: isSmallScreen ? 70 : 80,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: buttonColor,
            foregroundColor: textColor,
            padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            side: BorderSide(color: outlineColor),
            elevation: isDark ? 0 : 2,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              number,
              style: TextStyle(
                fontSize: isSmallScreen ? 32 : 36,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// アクションボタンウィジェット
class CalculatorActionButton extends StatelessWidget {
  const CalculatorActionButton({
    super.key,
    required this.icon,
    this.label,
    required this.onPressed,
    required this.color,
    this.isPrimary = false,
    required this.isSmallScreen,
    required this.buttonColor,
    required this.onPrimaryColor,
    required this.isDark,
  });

  final IconData icon;
  final String? label;
  final VoidCallback onPressed;
  final Color color;
  final bool isPrimary;
  final bool isSmallScreen;
  final Color buttonColor;
  final Color onPrimaryColor;
  final bool isDark;

  Color _getActionButtonColor() {
    if (isPrimary) {
      return color;
    } else {
      return buttonColor;
    }
  }

  Color _getActionButtonForegroundColor() {
    if (isPrimary) {
      return onPrimaryColor;
    } else {
      return color;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SizedBox(
        height: label != null
            ? (isSmallScreen ? 40 : 50)
            : (isSmallScreen ? 50 : 60),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: _getActionButtonColor(),
            foregroundColor: _getActionButtonForegroundColor(),
            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            side: isPrimary
                ? null
                : BorderSide(color: color.withValues(alpha: 0.3)),
            elevation: isDark ? (isPrimary ? 2 : 0) : (isPrimary ? 3 : 1),
          ),
          child: label != null
              ? FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: isSmallScreen ? 18 : 24),
                      SizedBox(width: isSmallScreen ? 6 : 8),
                      Text(
                        label!,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isSmallScreen ? 12 : 14,
                        ),
                      ),
                    ],
                  ),
                )
              : Icon(icon, size: isSmallScreen ? 20 : 24),
        ),
      ),
    );
  }
}
