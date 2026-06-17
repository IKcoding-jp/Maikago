// Firebase Cloud Functions を呼び出すためのサービス
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:maikago/services/debug_service.dart';

/// Firebase Cloud Functions を呼び出すためのサービス
class CloudFunctionsService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 認証されたユーザーでCloud Functionsを呼び出す
  Future<dynamic> callFunction(
      String functionName, Map<String, dynamic> data) async {
    try {
      // 認証状態を確認
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('ユーザーが認証されていません');
      }

      // httpsCallable は自動で認証トークンを送信するため、手動送信は不要
      final callable = _functions.httpsCallable(functionName);
      final result = await callable.call(data);

      return result.data;
    } catch (e) {
      DebugService().logError('Cloud Functions呼び出しエラー: $functionName - $e');
      rethrow;
    }
  }

  /// 画像解析用のCloud Functionsを呼び出す
  Future<Map<String, dynamic>> analyzeImage(String imageUrl) async {
    try {
      final result = await callFunction('analyzeImage', {
        'imageUrl': imageUrl,
        'timestamp': DateTime.now().toIso8601String(),
      });
      return result as Map<String, dynamic>;
    } catch (e) {
      DebugService().logError('画像解析エラー: $e');
      rethrow;
    }
  }

  /// 商品情報取得用のCloud Functionsを呼び出す
  Future<Map<String, dynamic>> getProductInfo(String productId) async {
    try {
      final result = await callFunction('getProductInfo', {
        'productId': productId,
      });

      return result as Map<String, dynamic>;
    } catch (e) {
      DebugService().logError('商品情報取得エラー: $e');
      rethrow;
    }
  }

  /// エラーハンドリング用のヘルパーメソッド
  String getErrorMessage(dynamic error) {
    if (error is FirebaseFunctionsException) {
      switch (error.code) {
        case 'unavailable':
          return 'サービスが一時的に利用できません';
        case 'permission-denied':
          return 'アクセス権限がありません';
        case 'unauthenticated':
          return '認証が必要です';
        case 'invalid-argument':
          return '無効なパラメータです';
        case 'not-found':
          return 'リソースが見つかりません';
        case 'already-exists':
          return '既に存在します';
        case 'resource-exhausted':
          return 'リソースが不足しています';
        case 'failed-precondition':
          return '前提条件が満たされていません';
        case 'aborted':
          return '操作が中止されました';
        case 'out-of-range':
          return '範囲外の値です';
        case 'unimplemented':
          return '実装されていません';
        case 'internal':
          return '内部エラーが発生しました';
        case 'data-loss':
          return 'データが失われました';
        default:
          return 'エラーが発生しました: ${error.message}';
      }
    }
    return '予期しないエラーが発生しました: $error';
  }
}
