import 'package:flutter/material.dart';

import 'package:maikago/screens/drawer/settings/settings_font.dart';

/// アプリ全体の色定義を管理するクラス
class AppColors {
  // === ブランドカラー ===
  static const Color primary = Color(0xFFFFB6C1);
  static const Color onPrimary = Colors.white;
  static const Color secondary = Color(0xFFB5EAD7);
  static const Color tertiary = Color(0xFFC7CEEA);
  static const Color accent = Color(0xFFFFDAC1);

  // === 背景・表面色 ===
  static const Color background = Color(0xFFFFF1F8);
  static const Color surface = Color(0xFFFFF1F8);
  static const Color lightBackground = Color(0xFFF8F9FA);

  // === セマンティックカラー ===
  static const Color error = Color(0xFFE57373);
  static const Color success = Color(0xFF81C784);
  static const Color warning = Color(0xFFFFB74D);
  static const Color info = Color(0xFF64B5F6);

  // === テキスト色 ===
  static const Color textPrimary = Colors.black87;
  static const Color textSecondary = Colors.black54;
  static const Color textDisabled = Colors.black38;
  static const Color headingDark = Color(0xFF2C3E50);
  static const Color subtextGrey = Color(0xFF7F8C8D);

  // === ボーダー・シャドウ ===
  static const Color border = Color(0xFFE0E0E0);
  static const Color shadow = Color(0x1A000000);

  // === プロモーション・プレミアム ===
  static const Color promoPink = Color(0xFFFFC0CB);

  // === 機能説明・装飾色 ===
  static const Color featureGreen = Color(0xFF90EE90);
  static const Color featureSky = Color(0xFF87CEEB);
  static const Color featureOrange = Color(0xFFFFA500);
  static const Color featureGold = Color(0xFFFFD700);
  static const Color featureMaterialGreen = Color(0xFF4CAF50);
  static const Color featureMaterialBlue = Color(0xFF2196F3);
  static const Color featureMaterialOrange = Color(0xFFFF9800);
  static const Color featurePurple = Color(0xFF9C27B0);
  static const Color featureRed = Color(0xFFE74C3C);
  static const Color featurePremiumBlue = Color(0xFF3498DB);
  static const Color featurePremiumGreen = Color(0xFF2ECC71);

  // === カメラUI色 ===
  static const Color cameraBackground = Colors.black;
  static const Color cameraForeground = Colors.white;
  static const Color cameraDisabled = Colors.grey;

  // === 機能説明・装飾色（追加分） ===
  static const Color featureBlue = Color(0xFF2196F3);
  static const Color featureCyan = Color(0xFF00BCD4);
  static const Color featureDeepPurple = Color(0xFF673AB7);
  static const Color featureTeal = Color(0xFF009688);
  static const Color featureIndigo = Color(0xFF3F51B5);
  static const Color featureAmber = Color(0xFFFFC107);
  static const Color featurePink = Color(0xFFE91E63);
  static const Color featureLightBlue = Color(0xFF03A9F4);
  static const Color featureLightGreen = Color(0xFF8BC34A);
  static const Color featureDeepOrange = Color(0xFFFF5722);

  // === ステータス色 ===
  static const Color statusInDevelopment = Color(0xFFFF9800);
  static const Color statusPlanned = Color(0xFF2196F3);

  // === ダークテーマ固有色 ===
  static const Color darkBackground = Color(0xFF1C1C1C);
  static const Color darkSurface = Color(0xFF1C1C1C);
  static const Color darkCard = Color(0xFF2B2B2B);
  static const Color darkCardAlt = Color(0xFF333333);
  static const Color darkButton = Color(0xFF3A3A3A);
}

/// アプリ全体のテーマ定義を管理するクラス
class SettingsTheme {
  /// テーマデータを生成
  static ThemeData generateTheme({
    required String selectedTheme,
    required String selectedFont,
    double fontSize = 16.0,
  }) {
    Color primary, secondary, surface;
    Color onPrimary, onSurface;

    // テキストテーマを先に取得
    final TextTheme textTheme = _getTextTheme(selectedFont, fontSize);

    // ライトテーマの surface は白に統一（Material 3 が surface から派生色を自動生成するため）
    switch (selectedTheme) {
      case 'light':
        primary = const Color(0xFF90A4AE);
        secondary = const Color(0xFFCFD8DC); // グレー
        break;
      case 'dark':
        primary = const Color(0xFF757575);
        secondary = const Color(0xFF505050);
        break;
      case 'orange':
        primary = const Color(0xFFFFC107);
        secondary = const Color(0xFFFFE082); // オレンジ
        break;
      case 'green':
        primary = const Color(0xFF8BC34A);
        secondary = const Color(0xFFC5E1A5); // グリーン
        break;
      case 'blue':
        primary = const Color(0xFF2196F3);
        secondary = const Color(0xFF90CAF9); // ブルー
        break;
      case 'beige':
        primary = const Color(0xFFFFE0B2);
        secondary = const Color(0xFFFFECB3); // ベージュ
        break;
      case 'mint':
        primary = const Color(0xFFB5EAD7);
        secondary = const Color(0xFFA8E6CF); // ミントグリーン
        break;
      case 'lavender':
        primary = const Color(0xFFB39DDB);
        secondary = const Color(0xFFD1C4E9); // ラベンダー
        break;
      case 'purple':
        primary = const Color(0xFF9C27B0);
        secondary = const Color(0xFFCE93D8); // パープル
        break;
      case 'teal':
        primary = const Color(0xFF009688);
        secondary = const Color(0xFF80CBC4); // ティール
        break;
      case 'amber':
        primary = const Color(0xFFFF9800);
        secondary = const Color(0xFFFFCC02); // アンバー
        break;
      case 'indigo':
        primary = const Color(0xFF3F51B5);
        secondary = const Color(0xFF9FA8DA); // インディゴ
        break;
      case 'soda':
        primary = const Color(0xFF81D4FA);
        secondary = const Color(0xFFB3E5FC); // ソーダブルー
        break;
      case 'coral':
        primary = const Color(0xFFFFAB91);
        secondary = const Color(0xFFFFCCBC); // コーラル
        break;
      default: // pink
        primary = const Color(0xFFFFC0CB); // パステルピンク
        secondary = const Color(0xFFFFE4E1); // より薄いピンク
    }
    surface = selectedTheme == 'dark' ? AppColors.darkCard : Colors.white;

    // テキストカラーの設定
    onPrimary = Colors.white;
    onSurface = selectedTheme == 'dark' ? Colors.white : Colors.black87;

    // 統一された背景色の設定
    final backgroundColor = _getBackgroundColor(selectedTheme);

    // 統一されたカード色の設定
    final cardColor =
        selectedTheme == 'dark' ? AppColors.darkCard : Colors.white;

    // 統一されたボーダー色の設定
    final borderColor = selectedTheme == 'dark'
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black87.withValues(alpha: 0.3);

    return ThemeData(
      colorScheme: ColorScheme(
        brightness:
            selectedTheme == 'dark' ? Brightness.dark : Brightness.light,
        primary: primary,
        onPrimary: onPrimary,
        secondary: secondary,
        onSecondary: Colors.white,
        surface: surface, // カード色と統一
        onSurface: onSurface, // 背景上のテキスト色
        error: Colors.red,
        onError: Colors.white,
      ),
      textTheme: textTheme.apply(
        bodyColor: selectedTheme == 'dark' ? Colors.white : Colors.black87,
        displayColor: selectedTheme == 'dark' ? Colors.white : Colors.black87,
      ),
      scaffoldBackgroundColor: backgroundColor,
      cardColor: cardColor,
      dividerColor: borderColor,
      dialogTheme: DialogThemeData(
        backgroundColor: cardColor,
      ),
      useMaterial3: true,
    );
  }

  /// テーマキーに対応するプライマリカラーを取得
  static Color getPrimaryColor(String selectedTheme) {
    switch (selectedTheme) {
      case 'light':
        return const Color(0xFF90A4AE);
      case 'dark':
        return const Color(0xFF757575);
      case 'orange':
        return const Color(0xFFFFC107);
      case 'green':
        return const Color(0xFF8BC34A);
      case 'blue':
        return const Color(0xFF2196F3);
      case 'beige':
        return const Color(0xFFFFE0B2);
      case 'mint':
        return const Color(0xFFB5EAD7);
      case 'lavender':
        return const Color(0xFFB39DDB);
      case 'purple':
        return const Color(0xFF9C27B0);
      case 'teal':
        return const Color(0xFF009688);
      case 'amber':
        return const Color(0xFFFF9800);
      case 'indigo':
        return const Color(0xFF3F51B5);
      case 'soda':
        return const Color(0xFF81D4FA);
      case 'coral':
        return const Color(0xFFFFAB91);
      case 'pink':
      default:
        return const Color(0xFFFFC0CB);
    }
  }

  /// フォントに基づいてテキストテーマを取得
  static TextTheme _getTextTheme(String selectedFont, double fontSize) {
    return FontSettings.getTextTheme(selectedFont, fontSize);
  }

  /// 背景色を取得
  static Color _getBackgroundColor(String theme) {
    if (theme == 'dark') {
      return AppColors.darkBackground;
    }
    return Colors.white;
  }

  /// テーマのラベルを取得
  static String getThemeLabel(String key) {
    switch (key) {
      case 'pink':
        return 'デフォルト';
      case 'light':
        return 'ライト';
      case 'dark':
        return 'ダーク';

      case 'orange':
        return 'オレンジ';
      case 'green':
        return 'グリーン';
      case 'soda':
        return 'ソーダ';
      case 'blue':
        return 'ブルー';
      case 'lavender':
        return 'ラベンダー';
      case 'coral':
        return 'コーラル';
      case 'beige':
        return 'ベージュ';
      case 'mint':
        return 'ミント';
      case 'purple':
        return 'パープル';
      case 'teal':
        return 'ティール';
      case 'amber':
        return 'アンバー';
      case 'indigo':
        return 'インディゴ';
      default:
        return 'デフォルト';
    }
  }

  /// 利用可能なテーマのリストを取得
  static List<Map<String, dynamic>> getAvailableThemes() {
    return [
      {'key': 'pink', 'label': 'デフォルト', 'color': const Color(0xFFFFB6C1)},
      {'key': 'light', 'label': 'ライト', 'color': const Color(0xFF90A4AE)},
      {'key': 'orange', 'label': 'オレンジ', 'color': const Color(0xFFFFC107)},
      {'key': 'dark', 'label': 'ダーク', 'color': const Color(0xFF757575)},
      {'key': 'green', 'label': 'グリーン', 'color': const Color(0xFF8BC34A)},
      {'key': 'soda', 'label': 'ソーダ', 'color': const Color(0xFF81D4FA)},
      {'key': 'blue', 'label': 'ブルー', 'color': const Color(0xFF2196F3)},
      {'key': 'lavender', 'label': 'ラベンダー', 'color': const Color(0xFFB39DDB)},
      {'key': 'coral', 'label': 'コーラル', 'color': const Color(0xFFFFAB91)},
      {'key': 'beige', 'label': 'ベージュ', 'color': const Color(0xFFFFE0B2)},
      {'key': 'mint', 'label': 'ミント', 'color': const Color(0xFFB5EAD7)},
      {'key': 'purple', 'label': 'パープル', 'color': const Color(0xFF9C27B0)},
      {'key': 'teal', 'label': 'ティール', 'color': const Color(0xFF009688)},
      {'key': 'amber', 'label': 'アンバー', 'color': const Color(0xFFFF9800)},
      {'key': 'indigo', 'label': 'インディゴ', 'color': const Color(0xFF3F51B5)},
    ];
  }

  /// 背景色に対するコントラスト色を取得
  static Color getContrastColor(Color backgroundColor) {
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  /// プライマリカラー背景上のアイコン・テキスト色を取得
  static Color getOnPrimaryColor(String selectedTheme) {
    return Colors.white;
  }

  /// テーマに応じたテキスト色を取得
  static Color getTextColor(String selectedTheme) {
    return selectedTheme == 'dark' ? Colors.white : Colors.black87;
  }

  /// テーマに応じたサブテキスト色を取得
  static Color getSubtextColor(String selectedTheme) {
    return selectedTheme == 'dark' ? Colors.white70 : Colors.black54;
  }

  /// テーマに応じたカード背景色を取得
  static Color getCardColor(String selectedTheme) {
    return selectedTheme == 'dark' ? AppColors.darkCard : Colors.white;
  }

  /// テーマに応じた画面背景色を取得（Scaffold内のContainer用）
  static Color getSurfaceColor(String selectedTheme) {
    return selectedTheme == 'dark' ? AppColors.darkSurface : Colors.transparent;
  }

  /// プライマリカラーの反対色（補色）を取得
  static Color getComplementaryColor(String selectedTheme) {
    final primary = getPrimaryColor(selectedTheme);
    final hsl = HSLColor.fromColor(primary);
    return hsl.withHue((hsl.hue + 180) % 360).toColor();
  }
}
