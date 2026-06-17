import 'package:flutter/material.dart';

/// アプリ全体で共有するルートScaffoldMessengerのキー。
///
/// `MaterialApp.router` の `scaffoldMessengerKey` に渡して使う。
/// 画面遷移で元の `BuildContext` が破棄された後でも、このキー経由なら
/// 通知を表示できる（保存・削除失敗→即画面遷移のシナリオ対策）。
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// `BuildContext` に依存せずエラーをSnackBarで表示する。
///
/// `rootScaffoldMessengerKey` 経由で表示するため、画面遷移後でも通知できる。
/// Messengerがまだ生成されていない場合は安全に無視する。
void showGlobalErrorSnackBar(dynamic error,
    {Duration duration = const Duration(seconds: 3)}) {
  final messenger = rootScaffoldMessengerKey.currentState;
  if (messenger == null) return;

  final message =
      error is String ? error : error.toString().replaceAll('Exception: ', '');
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Theme.of(messenger.context).colorScheme.error,
      duration: duration,
    ),
  );
}

/// エラーメッセージをSnackBarで表示する
///
/// [error] が Exception の場合は 'Exception: ' プレフィックスを自動除去する。
void showErrorSnackBar(BuildContext context, dynamic error,
    {Duration duration = const Duration(seconds: 3)}) {
  final message =
      error is String ? error : error.toString().replaceAll('Exception: ', '');
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Theme.of(context).colorScheme.error,
      duration: duration,
    ),
  );
}

/// 成功メッセージをSnackBarで表示する
void showSuccessSnackBar(BuildContext context, String message,
    {Duration duration = const Duration(seconds: 3)}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content:
          Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: Theme.of(context).colorScheme.primary,
      duration: duration,
    ),
  );
}

/// 情報メッセージをSnackBarで表示する
void showInfoSnackBar(BuildContext context, String message,
    {Duration duration = const Duration(seconds: 3)}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      duration: duration,
    ),
  );
}

/// 警告メッセージをSnackBarで表示する
void showWarningSnackBar(BuildContext context, String message,
    {Duration duration = const Duration(seconds: 3)}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Theme.of(context).colorScheme.secondary,
      duration: duration,
    ),
  );
}
