import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:maikago/services/debug_service.dart';

/// レシピから抽出された材料のモデル
class RecipeIngredient {
  RecipeIngredient({
    required this.name,
    this.quantity,
    required this.normalizedName,
    this.isExcluded = false,
    this.confidence = 1.0,
    this.notes,
  });

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) {
    return RecipeIngredient(
      name: json['name'] ?? '',
      quantity: json['quantity'],
      normalizedName: json['normalizedName'] ?? json['name'] ?? '',
      isExcluded: json['isExcluded'] ?? false,
      confidence: (json['confidence'] as num? ?? 1.0).toDouble(),
      notes: json['notes'],
    );
  }

  String name;
  String? quantity;
  String normalizedName;
  bool isExcluded;
  double confidence;
  String? notes;

  Map<String, dynamic> toJson() => {
        'name': name,
        'quantity': quantity,
        'normalizedName': normalizedName,
        'isExcluded': isExcluded,
        'confidence': confidence,
        'notes': notes,
      };
}

/// 解析結果をまとめるクラス
class RecipeParseResult {
  RecipeParseResult({required this.title, required this.ingredients});

  final String title;
  final List<RecipeIngredient> ingredients;
}

/// 解析エラーの種類
enum RecipeParseErrorType {
  textTooLong,
  unauthenticated,
  timeout,
  serverError,
  networkError,
  emptyResult,
  unknown,
}

/// 解析エラー
class RecipeParseError {
  RecipeParseError({required this.type, required this.message});

  final RecipeParseErrorType type;
  final String message;

  String get userMessage {
    switch (type) {
      case RecipeParseErrorType.textTooLong:
        return 'テキストが長すぎます。${RecipeParserService.maxRecipeTextLength}文字以下にしてください。';
      case RecipeParseErrorType.unauthenticated:
        return 'ログインが必要です。設定画面からGoogleログインしてください。';
      case RecipeParseErrorType.timeout:
        return 'サーバーの応答がタイムアウトしました。しばらくしてから再試行してください。';
      case RecipeParseErrorType.serverError:
        return 'サーバーエラーが発生しました: $message';
      case RecipeParseErrorType.networkError:
        return 'ネットワークエラーです。接続を確認してください。';
      case RecipeParseErrorType.emptyResult:
        return '材料を抽出できませんでした。材料セクションを含めて貼り付けてください。';
      case RecipeParseErrorType.unknown:
        return 'エラーが発生しました: $message';
    }
  }
}

class RecipeParserService {
  RecipeParserService();

  /// レシピテキストの最大文字数
  static const int maxRecipeTextLength = 5000;

  /// レシピテキストから材料を抽出する（Cloud Functions経由）
  /// 成功時は (RecipeParseResult, null)、失敗時は (null, RecipeParseError) を返す
  Future<(RecipeParseResult?, RecipeParseError?)> parseRecipe(
      String recipeText) async {
    // テキスト長制限チェック
    if (recipeText.length > maxRecipeTextLength) {
      DebugService().log('❌ レシピテキストが長すぎます（${recipeText.length}文字）');
      return (
        null,
        RecipeParseError(
            type: RecipeParseErrorType.textTooLong,
            message: '${recipeText.length}文字')
      );
    }

    try {
      DebugService().log('🤖 レシピ解析開始（Cloud Functions経由）...');

      final callable = FirebaseFunctions.instance.httpsCallable('parseRecipe');
      final response = await callable.call<Map<String, dynamic>>({
        'recipeText': recipeText,
      }).timeout(const Duration(seconds: 30));

      final data = response.data;

      if (data['success'] == true) {
        final title = data['title']?.toString() ?? 'レシピから取り込み';
        final ingredients = (data['ingredients'] as List? ?? [])
            .map((e) =>
                RecipeIngredient.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();

        if (ingredients.isEmpty) {
          DebugService().log('❌ レシピ解析: 材料が0件');
          return (
            null,
            RecipeParseError(
                type: RecipeParseErrorType.emptyResult, message: '材料0件')
          );
        }

        DebugService().log('✅ レシピ解析成功: 「$title」 ${ingredients.length}件の材料を抽出');
        return (
          RecipeParseResult(title: title, ingredients: ingredients),
          null
        );
      } else {
        final error = data['error']?.toString() ?? '不明';
        DebugService().log('❌ レシピ解析失敗: $error');
        return (
          null,
          RecipeParseError(
              type: RecipeParseErrorType.serverError, message: error)
        );
      }
    } on FirebaseFunctionsException catch (e) {
      DebugService().log('❌ レシピ解析エラー: [${e.code}] ${e.message}');
      if (e.code == 'unauthenticated') {
        return (
          null,
          RecipeParseError(
              type: RecipeParseErrorType.unauthenticated,
              message: e.message ?? '')
        );
      }
      if (e.code == 'deadline-exceeded') {
        return (
          null,
          RecipeParseError(
              type: RecipeParseErrorType.timeout, message: e.message ?? '')
        );
      }
      return (
        null,
        RecipeParseError(
            type: RecipeParseErrorType.serverError,
            message: '[${e.code}] ${e.message}')
      );
    } on TimeoutException {
      DebugService().log('❌ レシピ解析: クライアントタイムアウト（30秒）');
      return (
        null,
        RecipeParseError(
            type: RecipeParseErrorType.timeout, message: 'クライアント30秒タイムアウト')
      );
    } catch (e) {
      DebugService().log('❌ レシピ解析例外: $e');
      return (
        null,
        RecipeParseError(type: RecipeParseErrorType.unknown, message: '$e')
      );
    }
  }

  /// AIを使用して2つの材料が意味的に同一かどうかを判定する（Cloud Functions経由）
  Future<bool> isSameIngredient(String name1, String name2) async {
    // 完全に一致する場合は即座にtrue
    if (name1.trim() == name2.trim()) return true;

    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('checkIngredientSimilarity');
      final response = await callable.call<Map<String, dynamic>>({
        'name1': name1,
        'name2': name2,
      }).timeout(const Duration(seconds: 5));

      final data = response.data;
      return data['isSame'] == true;
    } catch (e) {
      DebugService().log('⚠️ 同一性判定失敗: $e');
      return false;
    }
  }
}
