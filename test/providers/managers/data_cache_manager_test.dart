import 'package:flutter_test/flutter_test.dart';
import 'package:maikago/providers/data_provider_state.dart';
import 'package:maikago/providers/managers/data_cache_manager.dart';
import '../../helpers/test_helpers.dart';
import '../../mocks.mocks.dart';

void main() {
  late DataCacheManager cacheManager;
  late MockDataService mockDataService;
  late DataProviderState state;

  setUp(() {
    mockDataService = MockDataService();
    state = DataProviderState(notifyListeners: () {});
    cacheManager = DataCacheManager(
      dataService: mockDataService,
      state: state,
    );
  });

  group('removeDuplicateShops', () {
    test('重複ショップがIDベースで除去される', () {
      final shop1 = createSampleShop(id: 'shop_1', name: 'ショップ1');
      final shop1Dup = createSampleShop(id: 'shop_1', name: 'ショップ1(重複)');
      final shop2 = createSampleShop(id: 'shop_2', name: 'ショップ2');

      cacheManager.shops
        ..add(shop1)
        ..add(shop2)
        ..add(shop1Dup);

      cacheManager.removeDuplicateShops();

      expect(cacheManager.shops.length, 2);
      expect(
          cacheManager.shops.map((s) => s.id).toList(), ['shop_1', 'shop_2']);
      // 最初に出現した方が保持される
      expect(cacheManager.shops[0].name, 'ショップ1');
    });

    test('重複がない場合に変更がない', () {
      final shop1 = createSampleShop(id: 'shop_1', name: 'ショップ1');
      final shop2 = createSampleShop(id: 'shop_2', name: 'ショップ2');

      cacheManager.shops
        ..add(shop1)
        ..add(shop2);

      cacheManager.removeDuplicateShops();

      expect(cacheManager.shops.length, 2);
    });

    test('空リストで安全に動作する', () {
      cacheManager.removeDuplicateShops();

      expect(cacheManager.shops, isEmpty);
    });

    test('全て同一IDの場合に1つだけ残る', () {
      cacheManager.shops
        ..add(createSampleShop(id: 'same', name: 'A'))
        ..add(createSampleShop(id: 'same', name: 'B'))
        ..add(createSampleShop(id: 'same', name: 'C'));

      cacheManager.removeDuplicateShops();

      expect(cacheManager.shops.length, 1);
      expect(cacheManager.shops[0].name, 'A');
    });
  });
}
