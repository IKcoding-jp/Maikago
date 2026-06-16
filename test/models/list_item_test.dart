import 'package:flutter_test/flutter_test.dart';
import 'package:maikago/models/list.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('ListItem', () {
    group('コンストラクタ', () {
      test('必須フィールドのみで生成できる', () {
        final item = ListItem(
          id: '1',
          name: 'テスト商品',
          quantity: 1,
          price: 100,
          shopId: '0',
        );

        expect(item.id, '1');
        expect(item.name, 'テスト商品');
        expect(item.quantity, 1);
        expect(item.price, 100);
        expect(item.shopId, '0');
        expect(item.discount, 0.0);
        expect(item.isChecked, false);
        expect(item.isReferencePrice, false);
        expect(item.sortOrder, 0);
        expect(item.isRecipeOrigin, false);
        expect(item.janCode, isNull);
        expect(item.productUrl, isNull);
        expect(item.imageUrl, isNull);
        expect(item.storeName, isNull);
        expect(item.recipeName, isNull);
      });

      test('全フィールドを指定して生成できる', () {
        final createdAt = DateTime(2026, 1, 1);
        final timestamp = DateTime(2026, 1, 2);
        final item = ListItem(
          id: '1',
          name: 'テスト商品',
          quantity: 3,
          price: 298,
          discount: 0.1,
          isChecked: true,
          shopId: 'shop_1',
          createdAt: createdAt,
          isReferencePrice: true,
          janCode: '4901234567890',
          productUrl: 'https://example.com',
          imageUrl: 'https://example.com/image.jpg',
          storeName: 'テスト店舗',
          timestamp: timestamp,
          sortOrder: 5,
          isRecipeOrigin: true,
          recipeName: 'カレー',
        );

        expect(item.discount, 0.1);
        expect(item.isChecked, true);
        expect(item.isReferencePrice, true);
        expect(item.janCode, '4901234567890');
        expect(item.productUrl, 'https://example.com');
        expect(item.imageUrl, 'https://example.com/image.jpg');
        expect(item.storeName, 'テスト店舗');
        expect(item.timestamp, timestamp);
        expect(item.sortOrder, 5);
        expect(item.isRecipeOrigin, true);
        expect(item.recipeName, 'カレー');
      });
    });

    group('copyWith', () {
      test('指定したフィールドのみ更新される', () {
        final item = createSampleItem(name: '元の名前', price: 100);
        final copied = item.copyWith(name: '新しい名前', price: 200);

        expect(copied.name, '新しい名前');
        expect(copied.price, 200);
        expect(copied.id, item.id);
        expect(copied.quantity, item.quantity);
        expect(copied.shopId, item.shopId);
      });

      test('フィールド未指定時は元の値が保持される', () {
        final item = createSampleItem(
          id: 'test_id',
          name: 'テスト',
          price: 500,
          quantity: 3,
        );
        final copied = item.copyWith();

        expect(copied.id, item.id);
        expect(copied.name, item.name);
        expect(copied.price, item.price);
        expect(copied.quantity, item.quantity);
        expect(copied.discount, item.discount);
        expect(copied.isChecked, item.isChecked);
        expect(copied.shopId, item.shopId);
      });
    });

    group('fromJson 型安全性', () {
      test('name/quantity/priceがnullの場合にデフォルト値が適用される', () {
        final json = <String, dynamic>{
          'id': '1',
          'name': null,
          'quantity': null,
          'price': null,
          'shopId': '0',
        };

        final item = ListItem.fromJson(json);

        expect(item.name, '');
        expect(item.quantity, 0);
        expect(item.price, 0);
      });

      test('数値がdoubleの場合でもintに変換される', () {
        final json = <String, dynamic>{
          'id': '1',
          'name': 'テスト',
          'quantity': 2.0,
          'price': 100.0,
          'shopId': '0',
        };

        final item = ListItem.fromJson(json);

        expect(item.quantity, 2);
        expect(item.price, 100);
      });
    });

    // Issue #164: 別バージョンや手動修正で型不一致・不正な値が混入しても
    // 例外を投げず、可能な範囲で復元する（壊れた1件で全体を道連れにしない）。
    group('fromJson 不正データ耐性（Issue #164）', () {
      test('quantity/priceが文字列でも例外を投げずパースする', () {
        final json = <String, dynamic>{
          'id': '1',
          'name': 'テスト',
          'quantity': '3',
          'price': '250',
          'shopId': '0',
        };

        final item = ListItem.fromJson(json);

        expect(item.quantity, 3);
        expect(item.price, 250);
      });

      test('quantity/priceが数値化できない文字列でもデフォルト値になる', () {
        final json = <String, dynamic>{
          'id': '1',
          'name': 'テスト',
          'quantity': 'abc',
          'price': '',
          'shopId': '0',
        };

        final item = ListItem.fromJson(json);

        expect(item.quantity, 0);
        expect(item.price, 0);
      });

      test('discountが文字列でも例外を投げずパースする', () {
        final json = <String, dynamic>{
          'id': '1',
          'name': 'テスト',
          'price': 100,
          'discount': '0.5',
          'shopId': '0',
        };

        final item = ListItem.fromJson(json);

        expect(item.discount, 0.5);
      });

      test('createdAt/timestampが不正な文字列でも例外を投げずnullになる', () {
        final json = <String, dynamic>{
          'id': '1',
          'name': 'テスト',
          'price': 100,
          'shopId': '0',
          'createdAt': 'not-a-date',
          'timestamp': '????',
        };

        final item = ListItem.fromJson(json);

        expect(item.createdAt, isNull);
        expect(item.timestamp, isNull);
      });
    });

    group('toJson / fromJson', () {
      test('正常にシリアライズ・デシリアライズできる', () {
        final createdAt = DateTime(2026, 1, 15, 10, 30, 0);
        final item = ListItem(
          id: 'item_1',
          name: 'りんご',
          quantity: 3,
          price: 298,
          discount: 0.2,
          isChecked: true,
          shopId: 'shop_1',
          createdAt: createdAt,
          isReferencePrice: true,
          janCode: '4901234567890',
          sortOrder: 2,
          isRecipeOrigin: true,
          recipeName: 'アップルパイ',
        );

        final json = item.toJson();
        final restored = ListItem.fromJson(json);

        expect(restored.id, item.id);
        expect(restored.name, item.name);
        expect(restored.quantity, item.quantity);
        expect(restored.price, item.price);
        expect(restored.discount, item.discount);
        expect(restored.isChecked, item.isChecked);
        expect(restored.shopId, item.shopId);
        expect(restored.createdAt, createdAt);
        expect(restored.isReferencePrice, item.isReferencePrice);
        expect(restored.janCode, item.janCode);
        expect(restored.sortOrder, item.sortOrder);
        expect(restored.isRecipeOrigin, item.isRecipeOrigin);
        expect(restored.recipeName, item.recipeName);
      });

      test('null値のフィールドを正しくハンドリングする', () {
        final json = {
          'id': '1',
          'name': 'テスト',
          'quantity': 1,
          'price': 100,
          'shopId': '0',
        };

        final item = ListItem.fromJson(json);

        expect(item.id, '1');
        expect(item.name, 'テスト');
        expect(item.discount, 0.0);
        expect(item.isChecked, false);
        expect(item.createdAt, isNull);
        expect(item.isReferencePrice, false);
        expect(item.janCode, isNull);
        expect(item.sortOrder, 0);
        expect(item.isRecipeOrigin, false);
        expect(item.recipeName, isNull);
      });

      test('IDがnullの場合は空文字列になる', () {
        final json = {
          'id': null,
          'name': 'テスト',
          'quantity': 1,
          'price': 100,
          'shopId': null,
        };

        final item = ListItem.fromJson(json);

        expect(item.id, '');
        expect(item.shopId, '');
      });
    });

    group('toMap / fromMap', () {
      test('正常にシリアライズ・デシリアライズできる', () {
        final item = createSampleItem(
          id: 'map_test',
          name: 'マップテスト',
          price: 500,
        );

        final map = item.toMap();
        final restored = ListItem.fromMap(map);

        expect(restored.id, item.id);
        expect(restored.name, item.name);
        expect(restored.price, item.price);
        expect(restored.quantity, item.quantity);
      });
    });

    group('priceWithTax', () {
      test('割引なしの場合、10%の税込み価格を返す', () {
        final item = createSampleItem(price: 100, discount: 0.0);
        // 100 * (1 - 0.0) = 100 → 100 * 1.1 = 110
        expect(item.priceWithTax, 110);
      });

      test('割引ありの場合、割引後に10%の税を加算する', () {
        final item = createSampleItem(price: 1000, discount: 0.2);
        // 1000 * (1 - 0.2) = 800 → 800 * 1.1 = 880
        expect(item.priceWithTax, 880);
      });

      test('価格0円の場合', () {
        final item = createSampleItem(price: 0, discount: 0.0);
        expect(item.priceWithTax, 0);
      });

      test('端数が発生する場合はroundされる', () {
        final item = createSampleItem(price: 99, discount: 0.0);
        // 99 * 1.1 = 108.9 → round() = 109
        expect(item.priceWithTax, 109);
      });

      test('割引と端数の組み合わせ', () {
        final item = createSampleItem(price: 298, discount: 0.1);
        // 298 * (1 - 0.1) = 298 * 0.9 = 268.2 → round() = 268
        // 268 * 1.1 = 294.8 → round() = 295
        expect(item.priceWithTax, 295);
      });
    });

    // Issue #157: discount/price/quantity の入力値バリデーション
    group('入力値バリデーション（Issue #157）', () {
      group('コンストラクタで範囲補正される', () {
        test('discountが1.0を超える場合は1.0に補正される', () {
          final item = createSampleItem(discount: 1.5);
          expect(item.discount, 1.0);
        });

        test('discountが0.0未満の場合は0.0に補正される', () {
          final item = createSampleItem(discount: -0.2);
          expect(item.discount, 0.0);
        });

        test('priceが負数の場合は0に補正される', () {
          final item = createSampleItem(price: -100);
          expect(item.price, 0);
        });

        test('quantityが負数の場合は0に補正される', () {
          final item = createSampleItem(quantity: -5);
          expect(item.quantity, 0);
        });

        test('正常範囲の値はそのまま保持される', () {
          final item = createSampleItem(discount: 0.3, price: 200, quantity: 2);
          expect(item.discount, 0.3);
          expect(item.price, 200);
          expect(item.quantity, 2);
        });
      });

      group('fromJsonで範囲補正される', () {
        ListItem restore(Map<String, dynamic> overrides) => ListItem.fromJson({
              'id': '1',
              'name': 'テスト',
              'quantity': 1,
              'price': 100,
              'shopId': '0',
              ...overrides,
            });

        test('discount=1.5（150%引き）は1.0に補正される', () {
          expect(restore({'discount': 1.5}).discount, 1.0);
        });

        test('discount=-0.2は0.0に補正される', () {
          expect(restore({'discount': -0.2}).discount, 0.0);
        });

        test('price=-100は0に補正される', () {
          expect(restore({'price': -100}).price, 0);
        });

        test('quantity=-5は0に補正される', () {
          expect(restore({'quantity': -5}).quantity, 0);
        });
      });

      group('copyWithで範囲補正される', () {
        test('範囲外のdiscountを渡すと補正される', () {
          final item = createSampleItem(discount: 0.1);
          expect(item.copyWith(discount: 2.0).discount, 1.0);
          expect(item.copyWith(discount: -1.0).discount, 0.0);
        });

        test('範囲外のprice/quantityを渡すと補正される', () {
          final item = createSampleItem();
          expect(item.copyWith(price: -50).price, 0);
          expect(item.copyWith(quantity: -3).quantity, 0);
        });
      });

      test('補正後の値は合計金額が負数にならない', () {
        // 壊れた割引率1.5でも (1 - clamp(1.5)) = 0 となり負数にならない
        final item = createSampleItem(price: 500, quantity: 2, discount: 1.5);
        final total =
            (item.price * item.quantity * (1 - item.discount)).round();
        expect(total, greaterThanOrEqualTo(0));
        expect(total, 0);
      });
    });
  });
}
