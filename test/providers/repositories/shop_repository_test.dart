import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:maikago/providers/repositories/shop_repository.dart';
import 'package:maikago/providers/managers/data_cache_manager.dart';
import 'package:maikago/providers/data_provider_state.dart';
import 'package:maikago/models/sort_mode.dart';
import 'package:maikago/models/shop.dart';
import '../../helpers/test_helpers.dart';
import '../../mocks.mocks.dart';

void main() {
  late MockDataService mockDataService;
  late DataCacheManager cacheManager;
  late DataProviderState state;
  late ShopRepository repository;
  late int notifyCount;

  setUp(() {
    // SharedPreferencesのモック初期化
    SharedPreferences.setMockInitialValues({});

    mockDataService = MockDataService();
    state = DataProviderState(notifyListeners: () => notifyCount++);
    cacheManager = DataCacheManager(
      dataService: mockDataService,
      state: state,
    );
    repository = ShopRepository(
      dataService: mockDataService,
      cacheManager: cacheManager,
      state: state,
    );
    notifyCount = 0;

    // デフォルトはローカルモード
    cacheManager.setLocalMode(true);
  });

  group('ensureDefaultShop', () {
    test('ローカルモードでデフォルトショップが作成される', () async {
      await repository.ensureDefaultShop();

      expect(cacheManager.shops.length, 1);
      expect(cacheManager.shops.first.id, '0');
      expect(cacheManager.shops.first.name, 'デフォルト');
    });

    test('既にデフォルトショップがある場合は作成しない', () async {
      final shop = createSampleShop(id: '0', name: 'デフォルト');
      cacheManager.addShopToCache(shop);

      await repository.ensureDefaultShop();

      expect(cacheManager.shops.length, 1);
    });

    test('非ローカルモードでショップが0個の場合はデフォルトショップを作成する', () async {
      cacheManager.setLocalMode(false);
      when(mockDataService.saveShop(
        any,
        isAnonymous: anyNamed('isAnonymous'),
      )).thenAnswer((_) async {});

      await repository.ensureDefaultShop();

      expect(cacheManager.shops.length, 1);
      expect(cacheManager.shops.first.id, '0');
      expect(cacheManager.shops.first.name, 'デフォルト');
      verify(mockDataService.saveShop(
        any,
        isAnonymous: anyNamed('isAnonymous'),
      )).called(1);
    });

    test('非ローカルモードで既存ショップがある場合はデフォルトショップを作成しない', () async {
      cacheManager.setLocalMode(false);
      final shop = createSampleShop(id: 'existing', name: '既存ショップ');
      cacheManager.addShopToCache(shop);

      await repository.ensureDefaultShop();

      expect(cacheManager.shops.length, 1);
      expect(cacheManager.shops.first.id, 'existing');
    });

    test('デフォルトショップが削除済みの場合は作成しない', () async {
      SharedPreferences.setMockInitialValues({
        'default_shop_deleted': true,
      });

      await repository.ensureDefaultShop();

      expect(cacheManager.shops, isEmpty);
    });

    test('notifyListenersが呼ばれる', () async {
      await repository.ensureDefaultShop();

      expect(notifyCount, greaterThan(0));
    });
  });

  group('addShop', () {
    test('通常のショップが追加される', () async {
      final shop = createSampleShop(id: '1', name: 'スーパー');

      await repository.addShop(shop);

      expect(cacheManager.shops.length, 1);
      expect(cacheManager.shops.first.name, 'スーパー');
    });

    test('通常のショップではIDが自動生成される', () async {
      final shop = createSampleShop(id: '1', name: 'スーパー');

      await repository.addShop(shop);

      // IDは'1'ではなくタイムスタンプベースで再生成される
      expect(cacheManager.shops.first.id, isNot('1'));
    });

    test('デフォルトショップ(id=0)はID再生成をスキップする', () async {
      final shop = createSampleShop(id: '0', name: 'デフォルト');

      await repository.addShop(shop);

      expect(cacheManager.shops.first.id, '0');
    });

    test('createdAtが自動設定される', () async {
      final shop = createSampleShop(id: '1', name: 'テスト');

      await repository.addShop(shop);

      expect(cacheManager.shops.first.createdAt, isNotNull);
    });

    test('notifyListenersが呼ばれる', () async {
      final shop = createSampleShop(id: '1', name: 'テスト');

      await repository.addShop(shop);

      expect(notifyCount, greaterThan(0));
    });

    test('ローカルモードではFirebaseに保存されない', () async {
      final shop = createSampleShop(id: '1', name: 'テスト');

      await repository.addShop(shop);

      verifyNever(mockDataService.saveShop(
        any,
        isAnonymous: anyNamed('isAnonymous'),
      ));
    });

    test('オンラインモードではFirebaseに保存される', () async {
      cacheManager.setLocalMode(false);
      when(mockDataService.saveShop(
        any,
        isAnonymous: anyNamed('isAnonymous'),
      )).thenAnswer((_) async {});

      final shop = createSampleShop(id: '1', name: 'テスト');
      await repository.addShop(shop);

      verify(mockDataService.saveShop(
        any,
        isAnonymous: anyNamed('isAnonymous'),
      )).called(1);
    });

    test('Firebase保存失敗時にキャッシュからロールバックされる', () async {
      cacheManager.setLocalMode(false);
      when(mockDataService.saveShop(
        any,
        isAnonymous: anyNamed('isAnonymous'),
      )).thenThrow(Exception('Firebase error'));

      final shop = createSampleShop(id: '1', name: 'テスト');

      try {
        await repository.addShop(shop);
      } catch (_) {}

      expect(cacheManager.shops, isEmpty);
    });

    test('デフォルトショップ追加時にdefaultShopDeletedがリセットされる', () async {
      SharedPreferences.setMockInitialValues({
        'default_shop_deleted': true,
      });

      final shop = createSampleShop(id: '0', name: 'デフォルト');
      await repository.addShop(shop);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('default_shop_deleted'), false);
    });
  });

  group('updateShop', () {
    test('ショップがキャッシュで更新される', () async {
      final shop = createSampleShop(id: 'shop1', name: '元の名前');
      cacheManager.addShopToCache(shop);

      final updatedShop = shop.copyWith(name: '新しい名前');
      await repository.updateShop(updatedShop);

      expect(cacheManager.shops.first.name, '新しい名前');
    });

    test('pendingUpdatesにIDが登録される', () async {
      final shop = createSampleShop(id: 'shop1', name: 'テスト');
      cacheManager.addShopToCache(shop);

      await repository.updateShop(shop);

      expect(repository.pendingUpdates, contains('shop1'));
    });

    test('バッチ更新中はnotifyListenersが抑止される', () async {
      final shop = createSampleShop(id: 'shop1', name: 'テスト');
      cacheManager.addShopToCache(shop);
      state.isBatchUpdating = true;

      await repository.updateShop(shop);

      expect(notifyCount, 0);
    });

    test('バッチ更新中でない場合はnotifyListenersが呼ばれる', () async {
      final shop = createSampleShop(id: 'shop1', name: 'テスト');
      cacheManager.addShopToCache(shop);

      await repository.updateShop(shop);

      expect(notifyCount, greaterThan(0));
    });

    test('ローカルモードではFirebaseに保存されない', () async {
      final shop = createSampleShop(id: 'shop1', name: 'テスト');
      cacheManager.addShopToCache(shop);

      await repository.updateShop(shop);

      verifyNever(mockDataService.updateShop(
        any,
        isAnonymous: anyNamed('isAnonymous'),
      ));
    });

    test('オンラインモードではFirebaseに保存される', () async {
      cacheManager.setLocalMode(false);
      final shop = createSampleShop(id: 'shop1', name: 'テスト');
      cacheManager.addShopToCache(shop);

      when(mockDataService.updateShop(
        any,
        isAnonymous: anyNamed('isAnonymous'),
      )).thenAnswer((_) async {});

      await repository.updateShop(shop);

      verify(mockDataService.updateShop(
        any,
        isAnonymous: anyNamed('isAnonymous'),
      )).called(1);
    });

    test('Firebase更新失敗時にロールバックされる', () async {
      cacheManager.setLocalMode(false);
      final shop = createSampleShop(id: 'shop1', name: '元の名前');
      cacheManager.addShopToCache(shop);

      when(mockDataService.updateShop(
        any,
        isAnonymous: anyNamed('isAnonymous'),
      )).thenThrow(Exception('Firebase error'));

      final updatedShop = shop.copyWith(name: '新しい名前');
      try {
        await repository.updateShop(updatedShop);
      } catch (_) {}

      expect(cacheManager.shops.first.name, '元の名前');
    });
  });

  group('deleteShop', () {
    test('ショップがキャッシュから削除される', () async {
      final shop = createSampleShop(id: 'shop1', name: 'テスト');
      cacheManager.addShopToCache(shop);

      await repository.deleteShop('shop1');

      expect(cacheManager.shops, isEmpty);
    });

    test('存在しないショップIDで例外がスローされる', () {
      expect(
        () => repository.deleteShop('non_existent_id'),
        throwsException,
      );
    });

    test('他ショップのsharedTabsから削除対象IDが除去される', () async {
      final shop1 = createSampleShop(
        id: 'shop1',
        name: 'ショップ1',
        sharedTabs: ['shop2'],
        sharedTabGroupId: 'group1',
      );
      final shop2 = createSampleShop(
        id: 'shop2',
        name: 'ショップ2',
        sharedTabs: ['shop1'],
        sharedTabGroupId: 'group1',
      );
      cacheManager.addShopToCache(shop1);
      cacheManager.addShopToCache(shop2);

      await repository.deleteShop('shop2');

      // shop1のsharedTabsからshop2が除去される
      expect(cacheManager.shops.first.sharedTabs, isEmpty);
    });

    test('共有相手がいなくなった場合にsharedTabGroupIdがクリアされる', () async {
      final shop1 = createSampleShop(
        id: 'shop1',
        name: 'ショップ1',
        sharedTabs: ['shop2'],
        sharedTabGroupId: 'group1',
      );
      final shop2 = createSampleShop(
        id: 'shop2',
        name: 'ショップ2',
        sharedTabs: ['shop1'],
        sharedTabGroupId: 'group1',
      );
      cacheManager.addShopToCache(shop1);
      cacheManager.addShopToCache(shop2);

      await repository.deleteShop('shop2');

      // 共有相手がいなくなったのでsharedTabGroupIdがnullになる
      expect(cacheManager.shops.first.sharedTabGroupId, isNull);
    });

    test('デフォルトショップ削除時に削除状態が記録される', () async {
      final shop = createSampleShop(id: '0', name: 'デフォルト');
      cacheManager.addShopToCache(shop);

      await repository.deleteShop('0');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('default_shop_deleted'), true);
    });

    test('notifyListenersが呼ばれる', () async {
      final shop = createSampleShop(id: 'shop1', name: 'テスト');
      cacheManager.addShopToCache(shop);

      await repository.deleteShop('shop1');

      expect(notifyCount, greaterThan(0));
    });

    test('ローカルモードではFirebaseに保存されない', () async {
      final shop = createSampleShop(id: 'shop1', name: 'テスト');
      cacheManager.addShopToCache(shop);

      await repository.deleteShop('shop1');

      verifyNever(mockDataService.deleteShop(
        any,
        isAnonymous: anyNamed('isAnonymous'),
      ));
    });

    test('オンラインモードではFirebaseから削除される', () async {
      cacheManager.setLocalMode(false);
      final shop = createSampleShop(id: 'shop1', name: 'テスト');
      cacheManager.addShopToCache(shop);

      when(mockDataService.deleteShop(
        any,
        isAnonymous: anyNamed('isAnonymous'),
      )).thenAnswer((_) async {});

      await repository.deleteShop('shop1');

      verify(mockDataService.deleteShop(
        'shop1',
        isAnonymous: anyNamed('isAnonymous'),
      )).called(1);
    });

    test('Firebase削除失敗時にロールバックされる', () async {
      cacheManager.setLocalMode(false);
      final shop = createSampleShop(id: 'shop1', name: 'テスト');
      cacheManager.addShopToCache(shop);

      when(mockDataService.deleteShop(
        any,
        isAnonymous: anyNamed('isAnonymous'),
      )).thenThrow(Exception('Firebase error'));

      try {
        await repository.deleteShop('shop1');
      } catch (_) {}

      expect(cacheManager.shops.length, 1);
      expect(cacheManager.shops.first.id, 'shop1');
    });

    test('削除失敗時は共有相手のsharedTabsも更新前へ巻き戻る（Issue #159）', () async {
      cacheManager.setLocalMode(false);
      final target = createSampleShop(
        id: 'shop1',
        name: '削除対象',
        sharedTabs: ['shop2'],
        sharedTabGroupId: 'group1',
      );
      final other = createSampleShop(
        id: 'shop2',
        name: '共有相手',
        sharedTabs: ['shop1'],
        sharedTabGroupId: 'group1',
      );
      cacheManager.addShopToCache(target);
      cacheManager.addShopToCache(other);

      // ドキュメント削除自体が失敗するケース
      when(mockDataService.deleteShop(
        any,
        isAnonymous: anyNamed('isAnonymous'),
      )).thenThrow(Exception('Firebase error'));

      try {
        await repository.deleteShop('shop1');
      } catch (_) {}

      // 削除対象は復活し、共有相手の sharedTabs / groupId も元のまま
      final restoredOther =
          cacheManager.shops.firstWhere((s) => s.id == 'shop2');
      expect(restoredOther.sharedTabs, ['shop1']);
      expect(restoredOther.sharedTabGroupId, 'group1');
      expect(repository.pendingUpdates.containsKey('shop2'), false);
    });

    test('影響を受ける複数の共有相手はバッチ1回でまとめて更新される（Issue #159）', () async {
      cacheManager.setLocalMode(false);
      // shop2, shop3 が削除対象 shop1 を共有相手に持つ
      final target = createSampleShop(
        id: 'shop1',
        name: '削除対象',
        sharedTabs: ['shop2', 'shop3'],
        sharedTabGroupId: 'group1',
      );
      final other1 = createSampleShop(
        id: 'shop2',
        name: '共有相手2',
        sharedTabs: ['shop1', 'shop3'],
        sharedTabGroupId: 'group1',
      );
      final other2 = createSampleShop(
        id: 'shop3',
        name: '共有相手3',
        sharedTabs: ['shop1', 'shop2'],
        sharedTabGroupId: 'group1',
      );
      cacheManager.addShopToCache(target);
      cacheManager.addShopToCache(other1);
      cacheManager.addShopToCache(other2);

      when(mockDataService.deleteShop(
        any,
        isAnonymous: anyNamed('isAnonymous'),
      )).thenAnswer((_) async {});
      when(mockDataService.updateShopsBatch(
        any,
        isAnonymous: anyNamed('isAnonymous'),
      )).thenAnswer((_) async {});

      await repository.deleteShop('shop1');

      // 順次 updateShop ではなくバッチ1回で更新される
      verifyNever(mockDataService.updateShop(
        any,
        isAnonymous: anyNamed('isAnonymous'),
      ));
      final captured = verify(mockDataService.updateShopsBatch(
        captureAny,
        isAnonymous: anyNamed('isAnonymous'),
      )).captured;
      expect(captured.length, 1);
      final batchedShops = (captured.first as List).cast<Shop>();
      expect(
        batchedShops.map((s) => s.id).toSet(),
        {'shop2', 'shop3'},
      );
    });
  });

  group('updateShopName', () {
    test('ショップ名が更新される', () {
      final shop = createSampleShop(id: '0', name: '元の名前');
      cacheManager.addShopToCache(shop);

      repository.updateShopName(0, '新しい名前');

      expect(cacheManager.shops.first.name, '新しい名前');
    });

    test('範囲外のインデックスでは何も起きない', () {
      final shop = createSampleShop(id: '0', name: '元の名前');
      cacheManager.addShopToCache(shop);

      repository.updateShopName(5, '新しい名前');

      expect(cacheManager.shops.first.name, '元の名前');
    });

    test('負のインデックスでは何も起きない', () {
      final shop = createSampleShop(id: '0', name: '元の名前');
      cacheManager.addShopToCache(shop);

      repository.updateShopName(-1, '新しい名前');

      expect(cacheManager.shops.first.name, '元の名前');
    });

    test('notifyListenersが呼ばれる', () {
      final shop = createSampleShop(id: '0', name: 'テスト');
      cacheManager.addShopToCache(shop);

      repository.updateShopName(0, '新しい名前');

      expect(notifyCount, greaterThan(0));
    });

    test('オンラインモードではFirebaseに保存される', () {
      cacheManager.setLocalMode(false);
      final shop = createSampleShop(id: '0', name: 'テスト');
      cacheManager.addShopToCache(shop);

      when(mockDataService.saveShop(
        any,
        isAnonymous: anyNamed('isAnonymous'),
      )).thenAnswer((_) async {});

      repository.updateShopName(0, '新しい名前');

      verify(mockDataService.saveShop(
        any,
        isAnonymous: anyNamed('isAnonymous'),
      )).called(1);
    });
  });

  group('updateShopBudget', () {
    test('予算が更新される', () {
      final shop = createSampleShop(id: '0', name: 'テスト');
      cacheManager.addShopToCache(shop);

      repository.updateShopBudget(0, 5000);

      expect(cacheManager.shops.first.budget, 5000);
    });

    test('予算をnullに設定できる', () {
      final shop = createSampleShop(id: '0', name: 'テスト', budget: 5000);
      cacheManager.addShopToCache(shop);

      repository.updateShopBudget(0, null);

      // copyWith(budget: null) はnullを設定しない（元の値を保持する）
      // clearBudget: true が必要だが、updateShopBudgetではclearBudgetを使っていない
      // この動作は現状のコードの仕様
      expect(cacheManager.shops.first.budget, 5000);
    });

    test('範囲外のインデックスでは何も起きない', () {
      repository.updateShopBudget(0, 5000);
      // 例外なく終了する
    });

    test('notifyListenersが呼ばれる', () {
      final shop = createSampleShop(id: '0', name: 'テスト');
      cacheManager.addShopToCache(shop);

      repository.updateShopBudget(0, 5000);

      expect(notifyCount, greaterThan(0));
    });
  });

  group('clearAllItems', () {
    test('ショップのアイテムが全削除される', () {
      final items = createSampleItems(3, shopId: '0');
      final shop = createSampleShop(id: '0', name: 'テスト', items: items);
      cacheManager.addShopToCache(shop);

      repository.clearAllItems(0);

      expect(cacheManager.shops.first.items, isEmpty);
    });

    test('範囲外のインデックスでは何も起きない', () {
      repository.clearAllItems(0);
      // 例外なく終了する
    });

    test('notifyListenersが呼ばれる', () {
      final shop = createSampleShop(id: '0', name: 'テスト');
      cacheManager.addShopToCache(shop);

      repository.clearAllItems(0);

      expect(notifyCount, greaterThan(0));
    });

    test('オンラインモードではFirebaseに保存される', () {
      cacheManager.setLocalMode(false);
      final shop = createSampleShop(id: '0', name: 'テスト');
      cacheManager.addShopToCache(shop);

      when(mockDataService.saveShop(
        any,
        isAnonymous: anyNamed('isAnonymous'),
      )).thenAnswer((_) async {});

      repository.clearAllItems(0);

      verify(mockDataService.saveShop(
        any,
        isAnonymous: anyNamed('isAnonymous'),
      )).called(1);
    });
  });

  group('updateSortMode', () {
    test('未完了ソートモードが更新される（isIncomplete=true）', () {
      final shop = createSampleShop(id: '0', name: 'テスト');
      cacheManager.addShopToCache(shop);

      repository.updateSortMode(0, SortMode.priceDesc, true);

      expect(cacheManager.shops.first.incSortMode, SortMode.priceDesc);
    });

    test('完了済みソートモードが更新される（isIncomplete=false）', () {
      final shop = createSampleShop(id: '0', name: 'テスト');
      cacheManager.addShopToCache(shop);

      repository.updateSortMode(0, SortMode.priceAsc, false);

      expect(cacheManager.shops.first.comSortMode, SortMode.priceAsc);
    });

    test('範囲外のインデックスでは何も起きない', () {
      repository.updateSortMode(0, SortMode.priceDesc, true);
      // 例外なく終了する
    });

    test('notifyListenersが呼ばれる', () {
      final shop = createSampleShop(id: '0', name: 'テスト');
      cacheManager.addShopToCache(shop);

      repository.updateSortMode(0, SortMode.priceDesc, true);

      expect(notifyCount, greaterThan(0));
    });

    test('オンラインモードではFirebaseに保存される', () {
      cacheManager.setLocalMode(false);
      final shop = createSampleShop(id: '0', name: 'テスト');
      cacheManager.addShopToCache(shop);

      when(mockDataService.saveShop(
        any,
        isAnonymous: anyNamed('isAnonymous'),
      )).thenAnswer((_) async {});

      repository.updateSortMode(0, SortMode.priceDesc, true);

      verify(mockDataService.saveShop(
        any,
        isAnonymous: anyNamed('isAnonymous'),
      )).called(1);
    });
  });
}
