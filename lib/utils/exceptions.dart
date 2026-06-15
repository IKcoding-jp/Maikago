/// アプリ共通の基底例外クラス
///
/// Service/Repository層でFirebase例外をアプリ固有の例外に変換する。
/// UI層では型による分岐でエラーメッセージを表示する。
class AppException implements Exception {
  const AppException(this.message, {this.code, this.originalError});

  final String message;
  final String? code;
  final dynamic originalError;

  @override
  String toString() => message;
}

/// リソースが見つからないエラー（Firestore document not found等）
class NotFoundError extends AppException {
  const NotFoundError([super.message = 'アイテムが見つかりませんでした。再度お試しください。'])
      : super(code: 'not-found');
}

/// 権限エラー（Firestore permission-denied等）
class PermissionDeniedError extends AppException {
  const PermissionDeniedError([super.message = '権限がありません。ログイン状態を確認してください。'])
      : super(code: 'permission-denied');
}

/// ネットワークエラー
class NetworkError extends AppException {
  const NetworkError([super.message = 'ネットワーク接続を確認してください。'])
      : super(code: 'network-error');
}

/// Firebase/Firestore例外をAppExceptionに変換するヘルパー
///
/// catchブロックで受け取った例外を型安全なAppExceptionに変換する。
/// [contextMessage] で操作コンテキストを付与できる（例: 'アイテムの更新'）。
AppException convertToAppException(dynamic e, {String? contextMessage}) {
  final errorString = e.toString();

  if (errorString.contains('not-found')) {
    return const NotFoundError();
  } else if (errorString.contains('permission-denied')) {
    return const PermissionDeniedError();
  }

  final message = contextMessage != null
      ? '$contextMessageに失敗しました。ネットワーク接続を確認してください。'
      : '操作に失敗しました。ネットワーク接続を確認してください。';
  return AppException(message, originalError: e);
}
