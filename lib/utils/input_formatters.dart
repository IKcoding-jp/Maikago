import 'package:flutter/services.dart';

/// 先頭ゼロを許可しないフォーマッター
///
/// 例: "01" → "1", "007" → "7"
/// "0" 単体は許可する（[allowSingleZero] が true の場合）
TextInputFormatter noLeadingZeroFormatter({bool allowSingleZero = false}) {
  return TextInputFormatter.withFunction((oldValue, newValue) {
    if (newValue.text.isEmpty) return newValue;
    if (allowSingleZero && newValue.text == '0') return newValue;
    if (newValue.text.startsWith('0') && newValue.text.length > 1) {
      return TextEditingValue(
        text: newValue.text.substring(1),
        selection: TextSelection.collapsed(
          offset: newValue.text.length - 1,
        ),
      );
    }
    return newValue;
  });
}

/// 数値入力の上限を超えさせないフォーマッター
///
/// Issue #157: 割引率(%)など範囲のある入力欄で使う。
/// [max] を超える値が入力された場合は変更を拒否し、変更前の値を維持する。
/// 数値として解釈できない入力（空文字を除く）も変更前を維持する。
TextInputFormatter maxValueFormatter(int max) {
  return TextInputFormatter.withFunction((oldValue, newValue) {
    if (newValue.text.isEmpty) return newValue;
    final value = int.tryParse(newValue.text);
    if (value == null) return oldValue;
    if (value > max) return oldValue;
    return newValue;
  });
}
