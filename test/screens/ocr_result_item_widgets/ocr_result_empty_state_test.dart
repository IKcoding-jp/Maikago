import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:maikago/screens/main/widgets/empty_state_guide.dart';

void main() {
  group('EmptyStateGuidePanel(購入済み)', () {
    testWidgets('エラーなくレンダリングされる', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyStateGuidePanel(isIncomplete: false),
          ),
        ),
      );

      expect(find.byType(EmptyStateGuidePanel), findsOneWidget);
    });

    testWidgets('dispose後にエラーが発生しない', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyStateGuidePanel(isIncomplete: false),
          ),
        ),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(),
          ),
        ),
      );
    });
  });
}
