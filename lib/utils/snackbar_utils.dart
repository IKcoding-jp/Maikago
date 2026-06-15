import 'package:flutter/material.dart';

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
