import 'package:flutter_test/flutter_test.dart';
import 'package:maikago/models/shop.dart';
import 'package:maikago/models/sort_mode.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('Shop', () {
    group('コンストラクタ', () {
      test('必須フィールドのみで生成できる', () {
        final shop = Shop(id: '0', name: 'デフォルト');

        expect(shop.id, '0');
        expect(shop.name, 'デフォルト');
        expect(shop.items, isEmpty);
        expect(shop.budget, isNull);
        expect(shop.createdAt, isNull);
        expect(shop.incSortMode, SortMode.dateNew);
        expect(shop.comSortMode, SortMode.dateNew);
        expect(shop.sharedTabs, isEmpty);
        expect(shop.sharedTabGroupId, isNull);
        expect(shop.sharedTabGroupIcon, isNull);
      });

      test('全フィールドを指定して生成できる', () {
        final items = [createSampleItem()];
        final createdAt = DateTime(2026, 1, 1);
        final shop = Shop(
          id: '1',
          name: 'スーパー',
          items: items,
          budget: 5000,
          createdAt: createdAt,
          incSortMode: SortMode.priceAsc,
          comSortMode: SortMode.dateOld,
          sharedTabs: ['tab1', 'tab2'],
          sharedTabGroupId: 'group_1',
          sharedTabGroupIcon: 'star',
        );

        expect(shop.items.length, 1);
        expect(shop.budget, 5000);
        expect(shop.createdAt, createdAt);
        expect(shop.incSortMode, SortMode.priceAsc);
        expect(shop.comSortMode, SortMode.dateOld);
        expect(shop.sharedTabs, ['tab1', 'tab2']);
        expect(shop.sharedTabGroupId, 'group_1');
        expect(shop.sharedTabGroupIcon, 'star');
      });
    });

    group('copyWith', () {
      test('指定したフィールドのみ更新される', () {
        final shop = createSampleShop(name: '元の名前', budget: 3000);
        final copied = shop.copyWith(name: '新しい名前', budget: 5000);

        expect(copied.name, '新しい名前');
        expect(copied.budget, 5000);
        expect(copied.id, shop.id);
      });

      test('clearBudgetでbudgetをnullにできる', () {
        final shop = createSampleShop(budget: 5000);
        final copied = shop.copyWith(clearBudget: true);

        expect(copied.budget, isNull);
      });

      test('clearSharedTabGroupIdでsharedTabGroupIdをnullにできる', () {
        final shop = createSampleShop(sharedTabGroupId: 'group_1');
        final copied = shop.copyWith(clearSharedTabGroupId: true);

        expect(copied.sharedTabGroupId, isNull);
      });

      test('itemsはイミュータブルである', () {
        final items = [createSampleItem(id: '1', name: '商品A')];
        final shop = createSampleShop(items: items);

        // 直接変更はUnsupportedErrorを発生させる
        expect(
          () => shop.items.add(createSampleItem(id: '2', name: '商品B')),
          throwsUnsupportedError,
        );
        expect(shop.items.length, 1);
      });

      test('copyWithでitemsを変更しても元のインスタンスに影響しない', () {
        final items = [createSampleItem(id: '1', name: '商品A')];
        final shop = createSampleShop(items: items);
        final copied = shop.copyWith(
          items: [...shop.items, createSampleItem(id: '2', name: '商品B')],
        );

        expect(shop.items.length, 1);
        expect(copied.items.length, 2);
      });
    });

    group('イミュータブル性', () {
      test('sharedTabsはイミュータブルである', () {
        final shop = createSampleShop(sharedTabs: ['tab1', 'tab2']);

        expect(
          () => shop.sharedTabs.add('tab3'),
          throwsUnsupportedError,
        );
        expect(shop.sharedTabs.length, 2);
      });
    });

    group('fromJson 型安全性', () {
      test('nameがnullの場合にデフォルト値が適用される', () {
        final json = <String, dynamic>{
          'id': '1',
          'name': null,
        };

        final shop = Shop.fromJson(json);
        expect(shop.name, '');
      });
    });

    group('toJson / fromJson', () {
      test('正常にシリアライズ・デシリアライズできる', () {
        final items = [
          createSampleItem(id: '1', name: 'りんご', price: 100),
          createSampleItem(id: '2', name: 'バナナ', price: 200),
        ];
        final createdAt = DateTime(2026, 2, 1, 10, 0, 0);
        final shop = Shop(
          id: 'shop_1',
          name: 'スーパー',
          items: items,
          budget: 5000,
          createdAt: createdAt,
          incSortMode: SortMode.priceAsc,
          comSortMode: SortMode.dateOld,
          sharedTabs: ['tab1'],
          sharedTabGroupId: 'group_1',
          sharedTabGroupIcon: 'cart',
        );

        final json = shop.toJson();
        final restored = Shop.fromJson(json);

        expect(restored.id, shop.id);
        expect(restored.name, shop.name);
        expect(restored.items.length, 2);
        expect(restored.items[0].name, 'りんご');
        expect(restored.items[1].name, 'バナナ');
        expect(restored.budget, 5000);
        expect(restored.createdAt, createdAt);
        expect(restored.incSortMode, SortMode.priceAsc);
        expect(restored.comSortMode, SortMode.dateOld);
        expect(restored.sharedTabs, ['tab1']);
        expect(restored.sharedTabGroupId, 'group_1');
        expect(restored.sharedTabGroupIcon, 'cart');
      });

      test('null値のフィールドを正しくハンドリングする', () {
        final json = {
          'id': '0',
          'name': 'テスト',
        };

        final shop = Shop.fromJson(json);

        expect(shop.id, '0');
        expect(shop.name, 'テスト');
        expect(shop.items, isEmpty);
        expect(shop.budget, isNull);
        expect(shop.createdAt, isNull);
        expect(shop.incSortMode, SortMode.dateNew);
        expect(shop.comSortMode, SortMode.dateNew);
        expect(shop.sharedTabs, isEmpty);
      });

      test('budgetが文字列の場合もパースできる', () {
        final json = {
          'id': '0',
          'name': 'テスト',
          'budget': '3000',
        };

        final shop = Shop.fromJson(json);
        expect(shop.budget, 3000);
      });

      test('不正なSortMode値はデフォルト値にフォールバックする', () {
        final json = {
          'id': '0',
          'name': 'テスト',
          'incSortMode': 'invalid_mode',
          'comSortMode': 'unknown',
        };

        final shop = Shop.fromJson(json);
        expect(shop.incSortMode, SortMode.dateNew);
        expect(shop.comSortMode, SortMode.dateNew);
      });
    });

    // Issue #164: Firestoreの壊れたデータ（null要素・型不一致・不正値）で
    // fromJsonがクラッシュせず、正常なアイテム/フィールドは読み込めること。
    group('fromJson 不正データ耐性（Issue #164）', () {
      test('items配列にnull要素が混ざっても例外を投げず除去される', () {
        final json = <String, dynamic>{
          'id': 'shop_1',
          'name': 'スーパー',
          'items': [
            {'id': '1', 'name': 'りんご', 'price': 100, 'shopId': 'shop_1'},
            null,
            {'id': '2', 'name': 'バナナ', 'price': 200, 'shopId': 'shop_1'},
          ],
        };

        final shop = Shop.fromJson(json);

        expect(shop.items.length, 2);
        expect(shop.items[0].name, 'りんご');
        expect(shop.items[1].name, 'バナナ');
      });

      test('items配列に型不一致の要素が混ざっても正常分は読み込める', () {
        final json = <String, dynamic>{
          'id': 'shop_1',
          'name': 'スーパー',
          'items': [
            {'id': '1', 'name': 'りんご', 'price': 100, 'shopId': 'shop_1'},
            'これはMapではない文字列',
            42,
            {'id': '2', 'name': 'バナナ', 'price': 200, 'shopId': 'shop_1'},
          ],
        };

        final shop = Shop.fromJson(json);

        expect(shop.items.length, 2);
        expect(shop.items.map((e) => e.name), ['りんご', 'バナナ']);
      });

      test('itemsがList型でない場合でも例外を投げず空になる', () {
        final json = <String, dynamic>{
          'id': 'shop_1',
          'name': 'スーパー',
          'items': {'broken': 'object'},
        };

        final shop = Shop.fromJson(json);

        expect(shop.items, isEmpty);
        expect(shop.name, 'スーパー');
      });

      test('createdAtが不正な文字列でも例外を投げずnullになる', () {
        final json = <String, dynamic>{
          'id': 'shop_1',
          'name': 'スーパー',
          'createdAt': 'broken-date',
        };

        final shop = Shop.fromJson(json);

        expect(shop.createdAt, isNull);
        expect(shop.name, 'スーパー');
      });

      test('budgetがdouble値でも正しくintにパースされる', () {
        final json = <String, dynamic>{
          'id': 'shop_1',
          'name': 'スーパー',
          'budget': 3000.0,
        };

        final shop = Shop.fromJson(json);

        expect(shop.budget, 3000);
      });

      test('壊れたアイテムを含むショップでも個々のアイテムが復元される', () {
        // priceが数値化できない壊れたアイテムが混ざっても、
        // そのアイテムはスキップされ、残りは読み込める。
        final json = <String, dynamic>{
          'id': 'shop_1',
          'name': 'スーパー',
          'items': [
            {'id': '1', 'name': '正常', 'price': 100, 'shopId': 'shop_1'},
            {'id': '2', 'name': '文字列price', 'price': '250', 'shopId': 'shop_1'},
          ],
        };

        final shop = Shop.fromJson(json);

        expect(shop.items.length, 2);
        expect(shop.items[1].price, 250);
      });
    });

    group('fromJson デュアルリード（Firestore後方互換）', () {
      test('旧フィールド名（sharedGroupId）から読み込める', () {
        final json = {
          'id': '0',
          'name': 'テスト',
          'sharedGroupId': 'old_group_1',
          'sharedGroupIcon': 'star',
        };

        final shop = Shop.fromJson(json);

        expect(shop.sharedTabGroupId, 'old_group_1');
        expect(shop.sharedTabGroupIcon, 'star');
      });

      test('新フィールド名（sharedTabGroupId）が旧フィールド名より優先される', () {
        final json = {
          'id': '0',
          'name': 'テスト',
          'sharedTabGroupId': 'new_group',
          'sharedGroupId': 'old_group',
          'sharedTabGroupIcon': 'heart',
          'sharedGroupIcon': 'star',
        };

        final shop = Shop.fromJson(json);

        expect(shop.sharedTabGroupId, 'new_group');
        expect(shop.sharedTabGroupIcon, 'heart');
      });

      test('新旧両方nullの場合はnull', () {
        final json = {
          'id': '0',
          'name': 'テスト',
        };

        final shop = Shop.fromJson(json);

        expect(shop.sharedTabGroupId, isNull);
        expect(shop.sharedTabGroupIcon, isNull);
      });

      test('toJsonは新フィールド名のみ出力する', () {
        final shop = Shop(
          id: '0',
          name: 'テスト',
          sharedTabGroupId: 'group_1',
          sharedTabGroupIcon: 'star',
        );

        final json = shop.toJson();

        expect(json.containsKey('sharedTabGroupId'), true);
        expect(json.containsKey('sharedTabGroupIcon'), true);
        expect(json.containsKey('sharedGroupId'), false);
        expect(json.containsKey('sharedGroupIcon'), false);
      });

      test('旧フィールドで保存→fromJson→toJsonで新フィールドに移行される', () {
        // Firestoreに旧フィールド名で保存されたデータをシミュレート
        final oldJson = {
          'id': 'shop_1',
          'name': 'スーパー',
          'sharedGroupId': 'legacy_group',
          'sharedGroupIcon': 'share',
          'sharedTabs': ['tab1'],
        };

        // fromJsonで読み込み（旧フィールドにフォールバック）
        final shop = Shop.fromJson(oldJson);
        expect(shop.sharedTabGroupId, 'legacy_group');

        // toJsonで新フィールド名に移行
        final newJson = shop.toJson();
        expect(newJson['sharedTabGroupId'], 'legacy_group');
        expect(newJson['sharedTabGroupIcon'], 'share');
        expect(newJson.containsKey('sharedGroupId'), false);
      });
    });

    group('toMap / fromMap', () {
      test('正常にシリアライズ・デシリアライズできる', () {
        final shop = createSampleShop(
          id: 'map_test',
          name: 'マップテスト',
          budget: 2000,
        );

        final map = shop.toMap();
        final restored = Shop.fromMap(map);

        expect(restored.id, shop.id);
        expect(restored.name, shop.name);
        expect(restored.budget, shop.budget);
      });
    });
  });
}
