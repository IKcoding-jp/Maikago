import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maikago/utils/input_formatters.dart';

void main() {
  // 入力UIに渡す TextEditingValue を組み立てるヘルパー
  TextEditingValue v(String text) => TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );

  group('maxValueFormatter（Issue #157）', () {
    test('上限以下の値はそのまま通す', () {
      final f = maxValueFormatter(100);
      expect(f.formatEditUpdate(v('5'), v('50')).text, '50');
      expect(f.formatEditUpdate(v('10'), v('100')).text, '100');
    });

    test('上限を超える値は拒否され、変更前の値を維持する', () {
      final f = maxValueFormatter(100);
      // 100 → 150 への変更は拒否され、直前の "100" が維持される
      expect(f.formatEditUpdate(v('100'), v('150')).text, '100');
    });

    test('空文字は許可する（入力途中のクリアを妨げない）', () {
      final f = maxValueFormatter(100);
      expect(f.formatEditUpdate(v('5'), v('')).text, '');
    });

    test('数値として解釈できない入力は変更前を維持する', () {
      final f = maxValueFormatter(100);
      expect(f.formatEditUpdate(v('50'), v('abc')).text, '50');
    });
  });
}
