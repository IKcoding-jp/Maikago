import 'package:flutter_test/flutter_test.dart';
import 'package:maikago/utils/calculation_utils.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('calcItemTotalRaw', () {
    test('割引なし: price × quantity', () {
      expect(calcItemTotalRaw(price: 100, quantity: 2, discount: 0.0), 200);
    });

    test('割引あり: 端数なし', () {
      // 1000 × 1 × (1 - 0.1) = 900
      expect(calcItemTotalRaw(price: 1000, quantity: 1, discount: 0.1), 900);
    });

    test('丸めは「×個数してから1回」: 101円×50%引×3個 = 152円（単価丸めの153ではない）', () {
      // (101 × 3 × 0.5) = 151.5 → round() = 152
      // 単価丸め(バグ派)なら (101×0.5).round()=51 → ×3 = 153 になる
      expect(calcItemTotalRaw(price: 101, quantity: 3, discount: 0.5), 152);
    });

    test('discountが1.0超はクランプされ合計0', () {
      expect(calcItemTotalRaw(price: 500, quantity: 2, discount: 1.5), 0);
    });

    test('discountが負はクランプされ割引なし扱い', () {
      expect(calcItemTotalRaw(price: 100, quantity: 1, discount: -0.5), 100);
    });

    test('価格0・数量0は0', () {
      expect(calcItemTotalRaw(price: 0, quantity: 5, discount: 0.0), 0);
      expect(calcItemTotalRaw(price: 100, quantity: 0, discount: 0.0), 0);
    });
  });

  group('calcItemTotal(ListItem)', () {
    test('ListItemの値で小計を返す（×個数してから丸め）', () {
      final item = createSampleItem(price: 101, quantity: 3, discount: 0.5);
      expect(calcItemTotal(item), 152);
    });
  });

  group('calcShopTotal', () {
    test('既定はチェック済みのみ合計', () {
      final shop = createSampleShop(items: [
        createSampleItem(id: '1', price: 100, quantity: 1, isChecked: true),
        createSampleItem(id: '2', price: 500, quantity: 1, isChecked: false),
      ]);
      expect(calcShopTotal(shop), 100);
    });

    test('checkedOnly:false は全件合計', () {
      final shop = createSampleShop(items: [
        createSampleItem(id: '1', price: 100, quantity: 1, isChecked: true),
        createSampleItem(id: '2', price: 500, quantity: 1, isChecked: false),
      ]);
      expect(calcShopTotal(shop, checkedOnly: false), 600);
    });

    test('合計はアイテム単位で丸めてから加算する', () {
      // 各アイテム 101×50%引×3個 = 152 → 合計 304
      final shop = createSampleShop(items: [
        createSampleItem(
            id: '1', price: 101, quantity: 3, discount: 0.5, isChecked: true),
        createSampleItem(
            id: '2', price: 101, quantity: 3, discount: 0.5, isChecked: true),
      ]);
      expect(calcShopTotal(shop), 304);
    });

    test('アイテムがない場合は0', () {
      expect(calcShopTotal(createSampleShop()), 0);
    });
  });

  group('calcDiscountedUnitPrice', () {
    test('1個あたりの割引後単価（数量を掛けない）', () {
      // 101 × 0.5 = 50.5 → round() = 51
      expect(calcDiscountedUnitPrice(101, 0.5), 51);
    });

    test('割引なしはそのまま', () {
      expect(calcDiscountedUnitPrice(298, 0.0), 298);
    });

    test('discountクランプ', () {
      expect(calcDiscountedUnitPrice(100, 1.5), 0);
      expect(calcDiscountedUnitPrice(100, -0.5), 100);
    });
  });
}
