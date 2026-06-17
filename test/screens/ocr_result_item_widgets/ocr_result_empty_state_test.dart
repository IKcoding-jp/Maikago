import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:maikago/screens/main/widgets/empty_state_purchased_guide.dart';

void main() {
  group('EmptyStatePurchasedGuide', () {
    testWidgets('エラーなくレンダリングされる', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyStatePurchasedGuide(),
          ),
        ),
      );

      expect(find.byType(EmptyStatePurchasedGuide), findsOneWidget);
    });

    testWidgets('dispose後にエラーが発生しない（AnimationControllerのリーク確認）',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyStatePurchasedGuide(),
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
