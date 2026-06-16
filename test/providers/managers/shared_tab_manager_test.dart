import 'package:flutter_test/flutter_test.dart';
import 'package:maikago/models/shop.dart';
import 'package:maikago/providers/managers/shared_tab_manager.dart';
import 'package:maikago/providers/managers/data_cache_manager.dart';
import 'package:maikago/providers/data_provider_state.dart';
import 'package:maikago/providers/repositories/shop_repository.dart';
import 'package:maikago/services/data_service.dart';
import '../../helpers/test_helpers.dart';

// --- Fake依存クラス ---

class FakeDataCacheManager implements DataCacheManager {
  @override
  List<Shop> shops = [];

  @override
  bool get isLocalMode => true;

  // テスト不要のメソッドは空実装
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class FakeShopRepository implements ShopRepository {
  @override
  final Map<String, DateTime> pendingUpdates = {};

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class FakeDataProviderState implements DataProviderState {
  int notifyCount = 0;

  @override
  bool isSynced = false;

  @override
  bool isBatchUpdating = false;

  @override
  bool shouldUseAnonymousSession = false;

  @override
  void notifyListeners() {
    notifyCount++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class FakeDataService implements DataService {
  final List<Shop> updatedShops = [];

  @override
  Future<void> updateShop(Shop shop, {bool isAnonymous = false}) async {
    updatedShops.add(shop);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  late SharedTabManager manager;
  late FakeDataCacheManager cacheManager;
  late FakeShopRepository shopRepository;
  late FakeDataProviderState state;
  late FakeDataService dataService;

  setUp(() {
    cacheManager = FakeDataCacheManager();
    shopRepository = FakeShopRepository();
    state = FakeDataProviderState();
    dataService = FakeDataService();
    manager = SharedTabManager(
      dataService: dataService,
      cacheManager: cacheManager,
      shopRepository: shopRepository,
      state: state,
    );
  });

  group('getDisplayTotal', () {
    test('チェック済みアイテムの合計を計算する', () {
      final shop = createSampleShop(items: [
        createSampleItem(price: 100, quantity: 2, isChecked: true),
        createSampleItem(id: '2', price: 200, quantity: 1, isChecked: true),
      ]);

      final total = manager.getDisplayTotal(shop);

      // 100*2 + 200*1 = 400
      expect(total, 400);
    });

    test('未チェックのアイテムは合計に含まれない', () {
      final shop = createSampleShop(items: [
        createSampleItem(price: 100, quantity: 1, isChecked: true),
        createSampleItem(id: '2', price: 500, quantity: 1, isChecked: false),
      ]);

      final total = manager.getDisplayTotal(shop);

      expect(total, 100);
    });

    test('アイテムがない場合は0', () {
      final shop = createSampleShop();

      expect(manager.getDisplayTotal(shop), 0);
    });

    test('割引率が適用される', () {
      final shop = createSampleShop(items: [
        createSampleItem(
            price: 1000, quantity: 1, discount: 0.1, isChecked: true),
      ]);

      final total = manager.getDisplayTotal(shop);

      // 1000 * 1 * (1 - 0.1) = 900
      expect(total, 900);
    });

    test('価格×個数×割引率の端数は四捨五入', () {
      final shop = createSampleShop(items: [
        createSampleItem(
            price: 333, quantity: 1, discount: 0.1, isChecked: true),
      ]);

      final total = manager.getDisplayTotal(shop);

      // 333 * 1 * 0.9 = 299.7 → 300
      expect(total, 300);
    });

    test('複数個×割引の丸めはアイテム単位で1回（Issue #156）', () {
      final shop = createSampleShop(items: [
        createSampleItem(
            price: 101, quantity: 3, discount: 0.5, isChecked: true),
      ]);

      // (101 * 3 * 0.5) = 151.5 → round() = 152
      // 単価で丸める旧実装なら (101*0.5).round()=51 → ×3 = 153 とズレていた
      expect(manager.getDisplayTotal(shop), 152);
    });
  });

  group('getSharedTabTotal', () {
    test('同じグループの全タブ合計を集計する', () {
      cacheManager.shops = [
        createSampleShop(
          id: 'shop1',
          sharedTabGroupId: 'group_1',
          items: [
            createSampleItem(price: 100, quantity: 1, isChecked: true),
          ],
        ),
        createSampleShop(
          id: 'shop2',
          sharedTabGroupId: 'group_1',
          items: [
            createSampleItem(price: 200, quantity: 1, isChecked: true),
          ],
        ),
        createSampleShop(
          id: 'shop3',
          items: [
            createSampleItem(price: 999, quantity: 1, isChecked: true),
          ],
        ),
      ];

      final total = manager.getSharedTabTotal('group_1');

      // shop1(100) + shop2(200) = 300（shop3は別グループ）
      expect(total, 300);
    });

    test('グループに属するショップがない場合は0', () {
      cacheManager.shops = [
        createSampleShop(id: 'shop1'),
      ];

      expect(manager.getSharedTabTotal('nonexistent'), 0);
    });
  });

  group('getSharedTabBudget', () {
    test('グループ内の最初の予算を返す', () {
      cacheManager.shops = [
        createSampleShop(
            id: 'shop1', sharedTabGroupId: 'group_1', budget: 5000),
        createSampleShop(
            id: 'shop2', sharedTabGroupId: 'group_1', budget: 3000),
      ];

      expect(manager.getSharedTabBudget('group_1'), 5000);
    });

    test('予算がないショップはスキップされる', () {
      cacheManager.shops = [
        createSampleShop(id: 'shop1', sharedTabGroupId: 'group_1'),
        createSampleShop(
            id: 'shop2', sharedTabGroupId: 'group_1', budget: 8000),
      ];

      expect(manager.getSharedTabBudget('group_1'), 8000);
    });

    test('全ショップに予算がない場合はnull', () {
      cacheManager.shops = [
        createSampleShop(id: 'shop1', sharedTabGroupId: 'group_1'),
      ];

      expect(manager.getSharedTabBudget('group_1'), isNull);
    });

    test('グループが存在しない場合はnull', () {
      cacheManager.shops = [];

      expect(manager.getSharedTabBudget('nonexistent'), isNull);
    });
  });

  group('updateSharedTab', () {
    test('2つのタブで共有を設定できる', () async {
      cacheManager.shops = [
        createSampleShop(id: 'shop1', name: 'ショップ1'),
        createSampleShop(id: 'shop2', name: 'ショップ2'),
      ];

      await manager.updateSharedTab('shop1', ['shop2']);

      final shop1 = cacheManager.shops[0];
      final shop2 = cacheManager.shops[1];

      // shop1のsharedTabsにshop2が含まれる
      expect(shop1.sharedTabs, ['shop2']);
      expect(shop1.sharedTabGroupId, isNotNull);

      // shop2のsharedTabsにshop1が含まれる
      expect(shop2.sharedTabs, ['shop1']);
      expect(shop2.sharedTabGroupId, shop1.sharedTabGroupId);
    });

    test('3つ以上のタブで共有を設定できる', () async {
      cacheManager.shops = [
        createSampleShop(id: 'a', name: 'A'),
        createSampleShop(id: 'b', name: 'B'),
        createSampleShop(id: 'c', name: 'C'),
      ];

      await manager.updateSharedTab('a', ['b', 'c']);

      final shopA = cacheManager.shops[0];
      final shopB = cacheManager.shops[1];
      final shopC = cacheManager.shops[2];

      expect(shopA.sharedTabs, ['b', 'c']);
      expect(shopB.sharedTabs.toSet(), {'a', 'c'});
      expect(shopC.sharedTabs.toSet(), {'a', 'b'});
    });

    test('notifyListenersが呼ばれる', () async {
      cacheManager.shops = [
        createSampleShop(id: 'shop1'),
        createSampleShop(id: 'shop2'),
      ];

      await manager.updateSharedTab('shop1', ['shop2']);

      expect(state.notifyCount, greaterThan(0));
    });

    test('pendingUpdatesが設定される', () async {
      cacheManager.shops = [
        createSampleShop(id: 'shop1'),
        createSampleShop(id: 'shop2'),
      ];

      await manager.updateSharedTab('shop1', ['shop2']);

      expect(shopRepository.pendingUpdates, contains('shop1'));
      expect(shopRepository.pendingUpdates, contains('shop2'));
    });

    test('空の選択でグループを解除できる', () async {
      cacheManager.shops = [
        createSampleShop(
          id: 'shop1',
          sharedTabGroupId: 'group_1',
          sharedTabs: ['shop2'],
        ),
        createSampleShop(
          id: 'shop2',
          sharedTabGroupId: 'group_1',
          sharedTabs: ['shop1'],
        ),
      ];

      await manager.updateSharedTab('shop1', []);

      final shop1 = cacheManager.shops[0];
      expect(shop1.sharedTabGroupId, isNull);
      expect(shop1.sharedTabs, isEmpty);
    });

    test('既存のグループIDが再利用される', () async {
      cacheManager.shops = [
        createSampleShop(
          id: 'shop1',
          sharedTabGroupId: 'existing_group',
          sharedTabs: ['shop2'],
        ),
        createSampleShop(id: 'shop2', sharedTabGroupId: 'existing_group'),
        createSampleShop(id: 'shop3'),
      ];

      await manager.updateSharedTab('shop1', ['shop2', 'shop3']);

      expect(cacheManager.shops[0].sharedTabGroupId, 'existing_group');
      expect(cacheManager.shops[2].sharedTabGroupId, 'existing_group');
    });

    test('解除されたタブからグループ参照が除去される', () async {
      cacheManager.shops = [
        createSampleShop(
          id: 'shop1',
          sharedTabGroupId: 'group_1',
          sharedTabs: ['shop2', 'shop3'],
        ),
        createSampleShop(
          id: 'shop2',
          sharedTabGroupId: 'group_1',
          sharedTabs: ['shop1', 'shop3'],
        ),
        createSampleShop(
          id: 'shop3',
          sharedTabGroupId: 'group_1',
          sharedTabs: ['shop1', 'shop2'],
        ),
      ];

      // shop3を解除
      await manager.updateSharedTab('shop1', ['shop2']);

      final shop3 = cacheManager.shops[2];
      // shop3のsharedTabsからshop1,shop2への参照が除去される
      expect(shop3.sharedTabs.contains('shop1'), false);
      expect(shop3.sharedTabs.contains('shop2'), false);
    });
  });

  group('removeFromSharedTab', () {
    test('グループから離脱できる', () async {
      cacheManager.shops = [
        createSampleShop(
          id: 'shop1',
          sharedTabGroupId: 'group_1',
          sharedTabs: ['shop2'],
        ),
        createSampleShop(
          id: 'shop2',
          sharedTabGroupId: 'group_1',
          sharedTabs: ['shop1'],
        ),
      ];

      await manager.removeFromSharedTab('shop1');

      final shop1 = cacheManager.shops[0];
      final shop2 = cacheManager.shops[1];

      expect(shop1.sharedTabs, isEmpty);
      expect(shop1.sharedTabGroupId, isNull);
      // shop2からもshop1への参照が除去される
      expect(shop2.sharedTabs.contains('shop1'), false);
    });

    test('存在しないショップIDでは何もしない', () async {
      cacheManager.shops = [
        createSampleShop(id: 'shop1'),
      ];

      await manager.removeFromSharedTab('nonexistent');

      // エラーが出ない
      expect(cacheManager.shops.length, 1);
    });

    test('notifyListenersが呼ばれる', () async {
      cacheManager.shops = [
        createSampleShop(
          id: 'shop1',
          sharedTabGroupId: 'group_1',
          sharedTabs: ['shop2'],
        ),
        createSampleShop(
          id: 'shop2',
          sharedTabGroupId: 'group_1',
          sharedTabs: ['shop1'],
        ),
      ];

      await manager.removeFromSharedTab('shop1');

      expect(state.notifyCount, greaterThan(0));
    });

    test('3タブグループから1タブ離脱しても残り2タブの関係は維持', () async {
      cacheManager.shops = [
        createSampleShop(
          id: 'a',
          sharedTabGroupId: 'g',
          sharedTabs: ['b', 'c'],
        ),
        createSampleShop(
          id: 'b',
          sharedTabGroupId: 'g',
          sharedTabs: ['a', 'c'],
        ),
        createSampleShop(
          id: 'c',
          sharedTabGroupId: 'g',
          sharedTabs: ['a', 'b'],
        ),
      ];

      await manager.removeFromSharedTab('a');

      final shopB = cacheManager.shops[1];
      final shopC = cacheManager.shops[2];

      // bとcの相互参照は維持（aへの参照のみ除去）
      expect(shopB.sharedTabs.contains('c'), true);
      expect(shopB.sharedTabs.contains('a'), false);
      expect(shopC.sharedTabs.contains('b'), true);
      expect(shopC.sharedTabs.contains('a'), false);
    });
  });

  group('syncSharedTabBudget', () {
    test('グループ全メンバーの予算を同期する', () async {
      cacheManager.shops = [
        createSampleShop(
            id: 'shop1', sharedTabGroupId: 'group_1', budget: 3000),
        createSampleShop(id: 'shop2', sharedTabGroupId: 'group_1'),
        createSampleShop(id: 'shop3', budget: 9999),
      ];

      await manager.syncSharedTabBudget('group_1', 5000);

      expect(cacheManager.shops[0].budget, 5000);
      expect(cacheManager.shops[1].budget, 5000);
      // shop3は別グループなので影響なし
      expect(cacheManager.shops[2].budget, 9999);
    });

    test('null予算で全メンバーの予算をクリアする', () async {
      cacheManager.shops = [
        createSampleShop(
            id: 'shop1', sharedTabGroupId: 'group_1', budget: 5000),
        createSampleShop(
            id: 'shop2', sharedTabGroupId: 'group_1', budget: 5000),
      ];

      await manager.syncSharedTabBudget('group_1', null);

      expect(cacheManager.shops[0].budget, isNull);
      expect(cacheManager.shops[1].budget, isNull);
    });

    test('0予算でも全メンバーの予算をクリアする', () async {
      cacheManager.shops = [
        createSampleShop(
            id: 'shop1', sharedTabGroupId: 'group_1', budget: 5000),
      ];

      await manager.syncSharedTabBudget('group_1', 0);

      expect(cacheManager.shops[0].budget, isNull);
    });

    test('notifyListenersが呼ばれる', () async {
      cacheManager.shops = [
        createSampleShop(id: 'shop1', sharedTabGroupId: 'group_1'),
      ];

      await manager.syncSharedTabBudget('group_1', 1000);

      expect(state.notifyCount, greaterThan(0));
    });
  });
}
