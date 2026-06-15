import 'package:flutter/material.dart';

/// ThemeData に対するユーティリティ拡張
extension ThemeUtils on ThemeData {
  /// カード用の影色を取得（ダークテーマで濃く、ライトテーマで薄く）
  Color get cardShadowColor => brightness == Brightness.dark
      ? Colors.black.withValues(alpha: 0.3)
      : Colors.black.withValues(alpha: 0.1);

  /// サブテキスト用の色を取得
  Color get subtextColor => colorScheme.onSurface.withValues(alpha: 0.6);
}
