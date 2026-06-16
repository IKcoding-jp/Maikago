import 'package:flutter_test/flutter_test.dart';

import 'package:maikago/models/ocr_session_result.dart';
import 'package:maikago/screens/main/widgets/bottom_summary_actions.dart';

/// Issue #155: OCR使用回数の消費可否判定
///
/// 確認画面のキャンセル・保存失敗ではカウントを消費せず、
/// 保存が成功したときのみ消費する仕様を検証する。
void main() {
  group('shouldConsumeOcrUsage', () {
    test('キャンセル（null）では消費しない', () {
      expect(shouldConsumeOcrUsage(null), isFalse);
    });

    test('保存失敗では消費しない', () {
      final result = SaveResult.failure('保存に失敗しました');
      expect(shouldConsumeOcrUsage(result), isFalse);
    });

    test('保存成功でのみ消費する', () {
      final result = SaveResult.success(message: '1件追加しました');
      expect(shouldConsumeOcrUsage(result), isTrue);
    });
  });
}
