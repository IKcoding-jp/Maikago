import 'package:cloud_functions/cloud_functions.dart';

/// 購入のサーバー検証結果。
class PurchaseVerificationResult {
  const PurchaseVerificationResult({required this.verified});

  /// サーバーが購入を検証し、プレミアムを有効化してよいと判断した場合 true。
  final bool verified;
}

/// サーバー検証が失敗・通信不能だったことを表す例外。
///
/// [code] は Cloud Functions のエラーコード（例: 'permission-denied',
/// 'unavailable', 'unimplemented'）。呼び出し側は再試行可否の判断に使う。
class PurchaseVerificationException implements Exception {
  PurchaseVerificationException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'PurchaseVerificationException($code): $message';
}

/// 購入をサーバー（Cloud Functions）で検証する責務を抽象化する。
///
/// クライアント内の [PurchaseDetails] は信頼せず、サーバー側で
/// Google Play / App Store のレシートを検証する（Issue #163 対応案#1/#3）。
/// テスト時は本インターフェースを実装したFakeに差し替える。
abstract class PurchaseVerifier {
  /// サーバー検証を実行する。
  ///
  /// 検証に成功すれば [PurchaseVerificationResult.verified] が true。
  /// 検証拒否・通信失敗時は [PurchaseVerificationException] を投げる。
  Future<PurchaseVerificationResult> verify({
    required String platform,
    required String productId,
    required String purchaseToken,
  });
}

/// Cloud Functions の `verifyPurchase` を呼ぶ本番実装。
class CloudFunctionsPurchaseVerifier implements PurchaseVerifier {
  CloudFunctionsPurchaseVerifier({FirebaseFunctions? functions})
      : _injectedFunctions = functions;

  final FirebaseFunctions? _injectedFunctions;

  // Firebase 初期化前にインスタンスを構築しても落ちないよう、
  // FirebaseFunctions.instance へのアクセスは verify() 実行時まで遅延する
  // （main.dart はサービスを Firebase.initializeApp より前に生成するため）。
  FirebaseFunctions get _functions =>
      _injectedFunctions ?? FirebaseFunctions.instance;

  @override
  Future<PurchaseVerificationResult> verify({
    required String platform,
    required String productId,
    required String purchaseToken,
  }) async {
    try {
      final callable = _functions.httpsCallable('verifyPurchase');
      final result = await callable.call(<String, dynamic>{
        'platform': platform,
        'productId': productId,
        'purchaseToken': purchaseToken,
      });

      final data = (result.data as Map?) ?? const {};
      return PurchaseVerificationResult(verified: data['verified'] == true);
    } on FirebaseFunctionsException catch (e) {
      throw PurchaseVerificationException(
        e.code,
        e.message ?? '購入検証に失敗しました',
      );
    }
  }
}
