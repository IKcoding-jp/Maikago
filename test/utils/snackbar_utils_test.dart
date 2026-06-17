import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maikago/utils/snackbar_utils.dart';

void main() {
  group('showGlobalErrorSnackBar', () {
    testWidgets('画面遷移後でもエラー通知が表示される', (tester) async {
      // ルートScaffoldMessengerを登録したアプリを用意する
      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: rootScaffoldMessengerKey,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          const Scaffold(body: Center(child: Text('次の画面'))),
                    ),
                  ),
                  child: const Text('進む'),
                ),
              ),
            ),
          ),
        ),
      );

      // 別画面へ遷移する（元のcontextは画面外になる）
      await tester.tap(find.text('進む'));
      await tester.pumpAndSettle();
      expect(find.text('次の画面'), findsOneWidget);

      // 遷移後にグローバル通知を出す（contextを渡さない）
      showGlobalErrorSnackBar('保存に失敗しました');
      await tester.pump();

      expect(find.text('保存に失敗しました'), findsOneWidget);
    });

    testWidgets('Exceptionプレフィックスは除去される', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: rootScaffoldMessengerKey,
          home: const Scaffold(body: SizedBox.shrink()),
        ),
      );

      showGlobalErrorSnackBar(Exception('ネットワークエラー'));
      await tester.pump();

      expect(find.text('ネットワークエラー'), findsOneWidget);
      expect(find.textContaining('Exception:'), findsNothing);
    });

    testWidgets('Messenger未登録でも例外を投げない', (tester) async {
      // currentStateがnullの状況でも安全に無視する
      expect(() => showGlobalErrorSnackBar('テスト'), returnsNormally);
    });
  });
}
