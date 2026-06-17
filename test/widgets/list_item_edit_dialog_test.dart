import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:maikago/models/list.dart';
import 'package:maikago/widgets/list_item_edit_dialog.dart';

ListItem _item({int price = 0, bool isChecked = false}) => ListItem(
      id: 'test-1',
      name: 'テストアイテム',
      quantity: 1,
      price: price,
      discount: 0,
      shopId: 'shop-1',
      isChecked: isChecked,
    );

/// GoRouter 付きでダイアログを表示し、保存ボタンを押す。
/// onUpdate コールバックで受け取った ListItem を返す。
Future<ListItem?> _tapSave(WidgetTester tester, ListItem item) async {
  ListItem? result;

  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => showDialog<void>(
                context: ctx,
                builder: (_) => ListItemEditDialog(
                  item: item,
                  onUpdate: (updated) => result = updated,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ],
  );

  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();

  await tester.tap(find.text('保存'));
  await tester.pumpAndSettle();

  return result;
}

void main() {
  group('ListItemEditDialog 自動購入済み', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('自動購入済みON・price>0・未チェック → 保存後 isChecked:true（バグ再発防止）',
        (tester) async {
      SharedPreferences.setMockInitialValues(
          {'auto_complete_on_price_input': true});

      final result =
          await _tapSave(tester, _item(price: 100, isChecked: false));

      expect(result?.isChecked, isTrue);
    });

    testWidgets('自動購入済みOFF・price>0・未チェック → 保存後 isChecked:false',
        (tester) async {
      SharedPreferences.setMockInitialValues(
          {'auto_complete_on_price_input': false});

      final result =
          await _tapSave(tester, _item(price: 100, isChecked: false));

      expect(result?.isChecked, isFalse);
    });

    testWidgets('自動購入済みON・price=0・未チェック → 保存後 isChecked:false', (tester) async {
      SharedPreferences.setMockInitialValues(
          {'auto_complete_on_price_input': true});

      final result = await _tapSave(tester, _item(price: 0, isChecked: false));

      expect(result?.isChecked, isFalse);
    });

    testWidgets('自動購入済みON・price>0・購入済み → 保存後 isChecked:true（状態維持）',
        (tester) async {
      SharedPreferences.setMockInitialValues(
          {'auto_complete_on_price_input': true});

      final result = await _tapSave(tester, _item(price: 100, isChecked: true));

      expect(result?.isChecked, isTrue);
    });
  });
}
