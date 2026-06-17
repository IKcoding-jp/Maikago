import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:maikago/screens/main/widgets/empty_state_guide.dart';

void main() {
  group('EmptyStateGuide', () {
    testWidgets('エラーなくレンダリングされる', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyStateGuide(),
          ),
        ),
      );

      expect(find.byType(EmptyStateGuide), findsOneWidget);
    });

    testWidgets('買い物カートアイコンが表示される', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyStateGuide(),
          ),
        ),
      );

      expect(find.byIcon(Icons.shopping_cart_outlined), findsOneWidget);
    });

    testWidgets('dispose後にエラーが発生しない', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyStateGuide(),
          ),
        ),
      );

      // 別のウィジェットに切り替えてdisposeを発火させる
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(),
          ),
        ),
      );

      // エラーなく完了することを確認
    });
  });
}
