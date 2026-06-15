import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:maikago/services/debug_service.dart';

/// 設定の保存・読み込み機能を管理するクラス
/// SharedPreferencesを使用してテーマ、フォント、フォントサイズ、カスタムテーマを永続化
class SettingsPersistence {
  static const String _themeKey = 'selected_theme';
  static const String _fontKey = 'selected_font';
  static const String _fontSizeKey = 'selected_font_size';
  static const String _customThemesKey = 'custom_themes';
  static const String _isFirstLaunchKey = 'is_first_launch';
  static const String _defaultShopDeletedKey = 'default_shop_deleted';
  static const String _cameraGuidelinesDontShowAgainKey =
      'camera_guidelines_dont_show_again';
  static const String _autoCompleteKey = 'auto_complete_on_price_input';
  static const String _strikethroughKey = 'strikethrough_on_completed_items';
  static const String _coachMarkCompletedKey = 'coach_mark_completed';

  // ── ジェネリックヘルパー ──────────────────────────────────

  /// SharedPreferencesに値を保存する汎用ヘルパー
  static Future<void> _save(String key, dynamic value, String caller) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value is String) {
        await prefs.setString(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is double) {
        await prefs.setDouble(key, value);
      } else if (value is bool) {
        await prefs.setBool(key, value);
      }
    } catch (e) {
      DebugService().logError('$caller エラー: $e');
    }
  }

  /// SharedPreferencesから値を読み込む汎用ヘルパー
  static Future<T> _load<T>(String key, T defaultValue, String caller) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.get(key);
      return (value is T) ? value : defaultValue;
    } catch (e) {
      DebugService().logError('$caller エラー: $e');
      return defaultValue;
    }
  }

  // ── テーマ・フォント設定 ──────────────────────────────────

  /// テーマを保存
  static Future<void> saveTheme(String theme) =>
      _save(_themeKey, theme, 'saveTheme');

  /// フォントを保存
  static Future<void> saveFont(String font) =>
      _save(_fontKey, font, 'saveFont');

  /// フォントサイズを保存
  static Future<void> saveFontSize(double fontSize) =>
      _save(_fontSizeKey, fontSize, 'saveFontSize');

  /// テーマを読み込み
  static Future<String> loadTheme() => _load(_themeKey, 'pink', 'loadTheme');

  /// フォントを読み込み
  static Future<String> loadFont() => _load(_fontKey, 'nunito', 'loadFont');

  /// フォントサイズを読み込み
  static Future<double> loadFontSize() =>
      _load(_fontSizeKey, 16.0, 'loadFontSize');

  // ── カスタムテーマ（JSON解析が必要なため個別実装）──────────

  /// カスタムテーマを読み込み
  static Future<Map<String, Map<String, Color>>> loadCustomThemes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final customThemesJson = prefs.getString(_customThemesKey);

      if (customThemesJson != null) {
        final customThemes = Map<String, Map<String, dynamic>>.from(
          json.decode(customThemesJson),
        );

        return customThemes.map(
          (name, colors) => MapEntry(
            name,
            colors.map((key, value) => MapEntry(key, Color(value as int))),
          ),
        );
      }

      return {};
    } catch (e) {
      DebugService().logError('loadCustomThemes エラー: $e');
      return {};
    }
  }

  /// 現在のカスタムテーマを読み込み
  static Future<Map<String, Color>> loadCurrentCustomTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentCustomThemeJson = prefs.getString('current_custom_theme');

      if (currentCustomThemeJson != null) {
        final currentCustomTheme = Map<String, dynamic>.from(
          json.decode(currentCustomThemeJson),
        );

        return currentCustomTheme.map(
          (key, value) => MapEntry(key, Color(value as int)),
        );
      }

      return {};
    } catch (e) {
      DebugService().logError('loadCurrentCustomTheme エラー: $e');
      return {};
    }
  }

  // ── フラグ系設定 ──────────────────────────────────────────

  /// 初回起動かどうかを確認
  static Future<bool> isFirstLaunch() =>
      _load(_isFirstLaunchKey, true, 'isFirstLaunch');

  /// 初回起動フラグを設定（初回起動完了後）
  static Future<void> setFirstLaunchComplete() =>
      _save(_isFirstLaunchKey, false, 'setFirstLaunchComplete');

  /// コーチマークが完了済みかどうかを確認
  static Future<bool> isCoachMarkCompleted() =>
      _load(_coachMarkCompletedKey, false, 'isCoachMarkCompleted');

  /// コーチマーク完了フラグを設定
  static Future<void> setCoachMarkCompleted() =>
      _save(_coachMarkCompletedKey, true, 'setCoachMarkCompleted');

  /// コーチマーク完了フラグをリセット（チュートリアル再表示用）
  static Future<void> resetCoachMark() =>
      _save(_coachMarkCompletedKey, false, 'resetCoachMark');

  /// デフォルトショップの削除状態を保存
  static Future<void> saveDefaultShopDeleted(bool deleted) =>
      _save(_defaultShopDeletedKey, deleted, 'saveDefaultShopDeleted');

  /// デフォルトショップの削除状態を読み込み
  static Future<bool> loadDefaultShopDeleted() =>
      _load(_defaultShopDeletedKey, false, 'loadDefaultShopDeleted');

  /// 自動購入済み設定を保存
  static Future<void> saveAutoComplete(bool enabled) =>
      _save(_autoCompleteKey, enabled, 'saveAutoComplete');

  /// 自動購入済み設定を読み込み
  static Future<bool> loadAutoComplete() =>
      _load(_autoCompleteKey, false, 'loadAutoComplete');

  /// 取り消し線設定を保存
  static Future<void> saveStrikethrough(bool enabled) =>
      _save(_strikethroughKey, enabled, 'saveStrikethrough');

  /// 取り消し線設定を読み込み
  static Future<bool> loadStrikethrough() =>
      _load(_strikethroughKey, false, 'loadStrikethrough');

  // ── タブ選択 ──────────────────────────────────────────────

  /// 選択されたタブインデックスを保存
  static Future<void> saveSelectedTabIndex(int index) =>
      _save('selected_tab_index', index, 'saveSelectedTabIndex');

  /// 選択されたタブインデックスを読み込み
  static Future<int> loadSelectedTabIndex() =>
      _load('selected_tab_index', 0, 'loadSelectedTabIndex');

  /// 選択されたタブIDを保存
  static Future<void> saveSelectedTabId(String tabId) =>
      _save('selected_tab_id', tabId, 'saveSelectedTabId');

  /// 選択されたタブIDを読み込み
  static Future<String?> loadSelectedTabId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('selected_tab_id');
    } catch (e) {
      DebugService().logError('loadSelectedTabId エラー: $e');
      return null;
    }
  }

  // ── タブ別予算・合計 ──────────────────────────────────────

  /// タブ別予算を保存
  static Future<void> saveTabBudget(String tabId, int? budget) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'budget_$tabId';
      if (budget != null) {
        await prefs.setInt(key, budget);
      } else {
        await prefs.remove(key);
      }
    } catch (e) {
      DebugService().logError('saveTabBudget エラー: $e');
    }
  }

  /// タブ別予算を読み込み
  static Future<int?> loadTabBudget(String tabId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('budget_$tabId');
    } catch (e) {
      DebugService().logError('loadTabBudget エラー: $e');
      return null;
    }
  }

  /// タブ別合計を保存
  static Future<void> saveTabTotal(String tabId, int total) =>
      _save('total_$tabId', total, 'saveTabTotal');

  /// タブ別合計を読み込み
  static Future<int> loadTabTotal(String tabId) =>
      _load('total_$tabId', 0, 'loadTabTotal');

  /// 現在の予算を取得（個別モード）
  static Future<int?> getCurrentBudget(String tabId) async {
    return await loadTabBudget(tabId);
  }

  /// 現在の合計を取得（個別モード）
  static Future<int> getCurrentTotal(String tabId) async {
    return await loadTabTotal(tabId);
  }

  /// 現在の予算を保存（個別モード）
  static Future<void> saveCurrentBudget(String tabId, int? budget) async {
    await saveTabBudget(tabId, budget);
  }

  /// 現在の合計を保存（個別モード）
  static Future<void> saveCurrentTotal(String tabId, int total) async {
    await saveTabTotal(tabId, total);
  }

  // ── 全設定読み込み ────────────────────────────────────────

  /// すべての設定を読み込み
  static Future<Map<String, dynamic>> loadAllSettings() async {
    final theme = await loadTheme();
    final font = await loadFont();
    final fontSize = await loadFontSize();
    final customThemes = await loadCustomThemes();

    return {
      'theme': theme,
      'font': font,
      'fontSize': fontSize,
      'customThemes': customThemes,
    };
  }

  // ── ゲストモード ────────────────────────────────────────

  static const String _guestModeKey = 'is_guest_mode';
  static const String _guestItemsKey = 'guest_items';
  static const String _guestShopsKey = 'guest_shops';

  /// ゲストモードフラグを保存
  static Future<void> saveGuestMode(bool isGuest) =>
      _save(_guestModeKey, isGuest, 'saveGuestMode');

  /// ゲストモードフラグを読み込み
  static Future<bool> loadGuestMode() =>
      _load(_guestModeKey, false, 'loadGuestMode');

  /// ゲストモードのアイテムデータを保存（JSON文字列）
  static Future<void> saveGuestItems(String itemsJson) =>
      _save(_guestItemsKey, itemsJson, 'saveGuestItems');

  /// ゲストモードのアイテムデータを読み込み
  static Future<String?> loadGuestItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_guestItemsKey);
    } catch (e) {
      DebugService().logError('loadGuestItems エラー: $e');
      return null;
    }
  }

  /// ゲストモードのショップデータを保存（JSON文字列）
  static Future<void> saveGuestShops(String shopsJson) =>
      _save(_guestShopsKey, shopsJson, 'saveGuestShops');

  /// ゲストモードのショップデータを読み込み
  static Future<String?> loadGuestShops() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_guestShopsKey);
    } catch (e) {
      DebugService().logError('loadGuestShops エラー: $e');
      return null;
    }
  }

  /// ゲストモードのデータをすべてクリア
  static Future<void> clearGuestData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.remove(_guestModeKey),
        prefs.remove(_guestItemsKey),
        prefs.remove(_guestShopsKey),
      ]);
    } catch (e) {
      DebugService().logError('clearGuestData エラー: $e');
    }
  }

  // ── カメラガイドライン ────────────────────────────────────

  /// カメラガイドラインを表示すべきかチェック
  static Future<bool> shouldShowCameraGuidelines() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dontShowAgain =
          prefs.getBool(_cameraGuidelinesDontShowAgainKey) ?? false;

      if (dontShowAgain) return false;

      return true;
    } catch (e) {
      DebugService().logError('shouldShowCameraGuidelines エラー: $e');
      return true;
    }
  }

  /// カメラガイドラインを「二度と表示しない」として設定
  static Future<void> setCameraGuidelinesDontShowAgain() => _save(
      _cameraGuidelinesDontShowAgainKey,
      true,
      'setCameraGuidelinesDontShowAgain');
}
