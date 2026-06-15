import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:maikago/providers/repositories/item_repository.dart';
import 'package:maikago/providers/managers/data_cache_manager.dart';
import 'package:maikago/providers/data_provider_state.dart';
import '../../helpers/test_helpers.dart';
import '../../mocks.mocks.dart';

void main() {
  late MockDataService mockDataService;
  late DataCacheManager cacheManager;
  late DataProviderState state;
  late ItemRepository repository;
  late int notifyCount;

  setUp(() {
    mockDataService = MockDataService();
    state = DataProviderState(notifyListeners: () => notifyCount++);
    cacheManager = DataCacheManager(
      dataService: mockDataService,
      state: state,
    );
    repository = ItemRepository(
      dataService: mockDataService,
      cacheManager: cacheManager,
      state: state,
    );
    notifyCount = 0;

    // デフォルトはローカルモード（Firebase依存を避ける）
    cacheManager.setLocalMode(true);
  });

  group('addItem', () {
    test('新規アイテムがキャッシュに追加される', () async {
      final item = createSampleItem(id: '', name: 'テスト商品', price: 100);

      await repository.addItem(item);

      expect(cacheManager.items.length, 1);
      expect(cacheManager.items.first.name, 'テスト商品');
      expect(cacheManager.items.first.price, 100);
    });

    test('IDが空の場合は自動生成される', () async {
      final item = createSampleItem(id: '', name: 'テスト');

      await repository.addItem(item);

      expect(cacheManager.items.first.id, isNotEmpty);
    });

    test('createdAtが自動設定される', () async {
      final item = createSampleItem(id: '', name: 'テスト');

      await repository.addItem(item);

      expect(cacheManager.items.first.createdAt, isNotNull);
    });

    test('新規アイテムはリストの先頭に追加される', () async {
      final item1 = createSampleItem(id: '', name: '商品1');
      final item2 = createSampleItem(id: '', name: '商品2');

      await repository.addItem(item1);
      await repository.addItem(item2);

      expect(cacheManager.items.length, 2);
      expect(cacheManager.items.first.name, '商品2');
    });

    test('重複IDの場合はupdateItemに委譲される', () async {
      final item = createSampleItem(id: 'existing_id', name: '元の名前');
      await repository.addItem(item);

      final updatedItem = createSampleItem(id: 'existing_id', name: '更新された名前');
      await repository.addItem(updatedItem);

      expect(cacheManager.items.length, 1);
      expect(cacheManager.items.first.name, '更新された名前');
    });

    test('対応するショップにもアイテムが追加される', () async {
      final shop = createSampleShop(id: '0', name: 'デフォルト');
      cacheManager.addShopToCache(shop);

      final item = createSampleItem(id: '', name: 'テスト商品', shopId: '0');

      await repository.addItem(item);

      expect(cacheManager.shops.first.items.length, 1);
      expect(cacheManager.shops.first.items.first.name, 'テスト商品');
    });

    test('存在しないショップIDのアイテムもキャッシュに追加される', () async {
      final item =
          createSampleItem(id: '', name: 'テスト', shopId: 'non_existent');

      await repository.addItem(item);

      expect(cacheManager.items.length, 1);
    });

    test('notifyListenersが呼ばれる', () async {
      final item = createSampleItem(id: '', name: 'テスト');

      await repository.addItem(item);

      expect(notifyCount, greaterThan(0));
    });

    test('ローカルモードではFirebaseに保存されない', () async {
      final item = createSampleItem(id: '', name: 'テスト');

      await repository.addItem(item);

      verifyNever(mockDataService.saveItem(
        any,
        isAnonymous: anyNamed('isAnonymous'),
      ));
    });

    test('オンラインモードではFirebaseに保存される', () async {
      cacheManager.setLocalMode(false);
      when(mockDataService.saveItem(
        any,
        isAnonymous: anyNamed('isAnonymous'),
      )).thenAnswer((_) async {});

      final item = createSampleItem(id: '', name: 'テスト');

      await repository.addItem(item);

      verify(mockDataService.saveItem(
        any,
        isAnonymous: anyNamed('isAnonymous'),
      )).called(1);
    });

    test('オンラインモードでFirebase保存成功時にisSyncedがtrueになる', () async {
      cacheManager.setLocalMode(false);
      when(mockDataService.saveItem(
        any,
        isAnonymous: anyNamed('isAnonymous'),
      )).thenAnswer((_) async {});

      final item = createSampleItem(id: '', name: 'テスト');

      await repository.addItem(item);

      expect(state.isSynced, true);
    });

    test('Firebase保存失敗時にキャッシュからロールバックされる', () async {
      cacheManager.setLocalMode(false);
      when(mockDataService.saveItem(
        any,
        isAnonymous: anyNamed('isAnonymous'),
      )).thenThrow(Exception('Firebase error'));

      final item = createSampleItem(id: '', name: 'テスト');

      expect(
        () => repository.addItem(item),
        throwsException,
      );

      // ロールバック後はキャッシュが空
      await Future.delayed(Duration.zero);
      expect(cacheManager.items, isEmpty);
    });

    test('Firebase保存失敗時にショップからもロールバックされる', () async {
      cacheManager.setLocalMode(false);
      final shop = createSampleShop(id: '0', name: 'デフォルト');
      cacheManager.addShopToCache(shop);

      when(mockDataService.saveItem(
        any,
        isAnonymous: anyNamed('isAnonymous'),
      )).thenThrow(Exception('Firebase error'));

      final item = createSampleItem(id: '', name: 'テスト', shopId: '0');

      try {
        await repository.addItem(item);
      } catch (_) {}

      expect(cacheManager.shops.first.items, isEmpty);
    });
  });

  group('updateItem', () {
    test('アイテムがキャッシュで更新される', () async {
      final item = createSampleItem(id: 'item1', name: '元の名前');
      cacheManager.addItemToCache(item);

      final updatedItem = item.copyWith(name: '新しい名前', price: 200);
      await repository.updateItem(updatedItem);

      expect(cacheManager.items.first.name, '新しい名前');
      expect(cacheManager.items.first.price, 200);
    });

    test('pendingUpdatesにIDが登録される', () async {
      final item = createSampleItem(id: 'item1', name: 'テスト');
      cacheManager.addItemToCache(item);

      await repository.updateItem(item);

      expect(repository.pendingUpdates, contains('item1'));
    });

    test('shopsリスト内のアイテムも同期更新される', () async {
      final item = createSampleItem(id: 'item1', name: '元の名前', shopId: '0');
      cacheManager.addItemToCache(item);
      final shop = createSampleShop(id: '0', name: 'デフォルト', items: [item]);
      cacheManager.addShopToCache(shop);

      final updatedItem = item.copyWith(name: '新しい名前');
      await repository.updateItem(updatedItem);

      expect(cacheManager.shops.first.items.first.name, '新しい名前');
    });

    test('notifyListenersが呼ばれる', () async {
      final item = createSampleItem(id: 'item1', name: 'テスト');
      cacheManager.addItemToCache(item);

      await repository.updateItem(item);

      expect(notifyCount, greaterThan(0));
    });

    test('ローカルモードではFirebaseに保存されない', () async {
      final item = createSampleItem(id: 'item1', name: 'テスト');
      cacheManager.addItemToCache(item);

      await repository.updateItem(item);

      verifyNever(mockDataService.updateItem(
        any,
        isAnonymous: anyNamed('isAnonymous'),
      ));
    });

    test('オンラインモードではFirebaseに保存される', () async {
      cacheManager.setLocalMode(false);
      final item = createSampleItem(id: 'item1', name: 'テスト');
      cacheManager.addItemToCache(item);

      when(mockDataService.updateItem(
        any,
        isAnonymous: anyNamed('isAnonymous'),
      )).thenAnswer((_) async {});

      await repository.updateItem(item);

      verify(mockDataService.updateItem(
        any,
        isAnonymous: anyNamed('isAnonymous'),
      )).called(1);
    });

    test('Firebase更新失敗時にAppExceptionがスローされる', () async {
      cacheManager.setLocalMode(false);
      final item = createSampleItem(id: 'item1', name: 'テスト');
      cacheManager.addItemToCache(item);

      when(mockDataService.updateItem(
        any,
        isAnonymous: anyNamed('isAnonymous'),
      )).thenThrow(Exception('Firebase error'));

      expect(
        () => repository.updateItem(item),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('updateItemsBatch', () {
    test('複数アイテムがバッチで更新される', () async {
      final items = createSampleItems(3, shopId: '0');
      for (final item in items) {
        cacheManager.addItemToCache(item);
      }

      final updatedItems =
          items.map((item) => item.copyWith(price: 999)).toList();
      final pendingShopUpdates = <String, DateTime>{};

      await repository.updateItemsBatch(
        updatedItems,
        pendingShopUpdates: pendingShopUpdates,
      );

      for (final item in cacheManager.items) {
        expect(item.price, 999);
      }
    });

    test('全アイテムIDがpendingUpdatesに登録される', () async {
      final items = createSampleItems(3, shopId: '0');
      for (final item in items) {
        cacheManager.addItemToCache(item);
      }
      final pendingShopUpdates = <String, DateTime>{};

      await repository.updateItemsBatch(
        items,
        pendingShopUpdates: pendingShopUpdates,
      );

      for (final item in items) {
        expect(repository.pendingUpdates, contains(item.id));
      }
    });

    test('shopsリスト内のアイテムも更新される', () async {
      final items = createSampleItems(2, shopId: '0');
      for (final item in items) {
        cacheManager.addItemToCache(item);
      }
      final shop = createSampleShop(id: '0', name: 'デフォルト', items: items);
      cacheManager.addShopToCache(shop);

      final updatedItems =
          items.map((item) => item.copyWith(price: 500)).toList();
      final pendingShopUpdates = <String, DateTime>{};

      await repository.updateItemsBatch(
        updatedItems,
        pendingShopUpdates: pendingShopUpdates,
      );

      for (final item in cacheManager.shops.first.items) {
        expect(item.price, 500);
      }
    });

    test('変更があったショップがpendingShopUpdatesに追加される', () async {
      final items = createSampleItems(1, shopId: '0');
      for (final item in items) {
        cacheManager.addItemToCache(item);
      }
      final shop = createSampleShop(id: '0', name: 'デフォルト', items: items);
      cacheManager.addShopToCache(shop);

      final updatedItems =
          items.map((item) => item.copyWith(price: 500)).toList();
      final pendingShopUpdates = <String, DateTime>{};

      await repository.updateItemsBatch(
        updatedItems,
        pendingShopUpdates: pendingShopUpdates,
      );

      expect(pendingShopUpdates, contains('0'));
    });

    test('オンラインモードではFirebaseにバッチ保存される', () async {
      cacheManager.setLocalMode(false);
      final items = createSampleItems(7, shopId: '0');
      for (final item in items) {
        cacheManager.addItemToCache(item);
      }

      when(mockDataService.updateItem(
        any,
        isAnonymous: anyNamed('isAnonymous'),
      )).thenAnswer((_) async {});

      final pendingShopUpdates = <String, DateTime>{};
      await repository.updateItemsBatch(
        items,
        pendingShopUpdates: pendingShopUpdates,
      );

      // 7アイテム → batchSize=5で2回のバッチ
      verify(mockDataService.updateItem(
        any,
        isAnonymous: anyNamed('isAnonymous'),
      )).called(7);
    });

    test('ローカルモードではFirebaseに保存されない', () async {
      final items = createSampleItems(3, shopId: '0');
      for (final item in items) {
        cacheManager.addItemToCache(item);
      }

      final pendingShopUpdates = <String, DateTime>{};
      await repository.updateItemsBatch(
        items,
        pendingShopUpdates: pendingShopUpdates,
      );

      verifyNever(mockDataService.updateItem(
        any,
        isAnonymous: anyNamed('isAnonymous'),
      ));
    });
  });

  group('applyReorderToCache', () {
    test('ショップがキャッシュで更新される', () {
      final shop = createSampleShop(id: '0', name: 'デフォルト');
      cacheManager.addShopToCache(shop);

      final updatedShop = shop.copyWith(name: '更新されたショップ');
      final pendingShopUpdates = <String, DateTime>{};

      repository.applyReorderToCache(
        updatedShop,
        [],
        pendingShopUpdates: pendingShopUpdates,
      );

      expect(cacheManager.shops.first.name, '更新されたショップ');
    });

    test('アイテムがキャッシュで更新される', () {
      final item = createSampleItem(id: 'item1', name: 'テスト', sortOrder: 0);
      cacheManager.addItemToCache(item);

      final updatedItem = item.copyWith(sortOrder: 5);
      final shop = createSampleShop(id: '0', name: 'デフォルト');
      cacheManager.addShopToCache(shop);

      final pendingShopUpdates = <String, DateTime>{};

      repository.applyReorderToCache(
        shop,
        [updatedItem],
        pendingShopUpdates: pendingShopUpdates,
      );

      expect(cacheManager.items.first.sortOrder, 5);
    });

    test('pendingUpdatesとpendingShopUpdatesに登録される', () {
      final item = createSampleItem(id: 'item1', name: 'テスト');
      cacheManager.addItemToCache(item);
      final shop = createSampleShop(id: 'shop1', name: 'テスト');
      cacheManager.addShopToCache(shop);

      final pendingShopUpdates = <String, DateTime>{};

      repository.applyReorderToCache(
        shop,
        [item],
        pendingShopUpdates: pendingShopUpdates,
      );

      expect(repository.pendingUpdates, contains('item1'));
      expect(pendingShopUpdates, contains('shop1'));
    });
  });

  group('persistReorderToFirebase', () {
    test('ローカルモードではFirebaseに保存されない', () async {
      final shop = createSampleShop(id: '0', name: 'デフォルト');
      final items = createSampleItems(3, shopId: '0');

      await repository.persistReorderToFirebase(shop, items);

      verifyNever(mockDataService.updateShop(
        any,
        isAnonymous: anyNamed('isAnonymous'),
      ));
    });

    test('オンラインモードではショップとアイテムがFirebaseに保存される', () async {
      cacheManager.setLocalMode(false);
      final shop = createSampleShop(id: '0', name: 'デフォルト');
      final items = createSampleItems(3, shopId: '0');

      when(mockDataService.updateShop(
        any,
        isAnonymous: anyNamed('isAnonymous'),
      )).thenAnswer((_) async {});
      when(mockDataService.updateItem(
        any,
        isAnonymous: anyNamed('isAnonymous'),
      )).thenAnswer((_) async {});

      await repository.persistReorderToFirebase(shop, items);

      verify(mockDataService.updateShop(
        any,
        isAnonymous: anyNamed('isAnonymous'),
      )).called(1);
      verify(mockDataService.updateItem(
        any,
        isAnonymous: anyNamed('isAnonymous'),
      )).called(3);
    });

    test('Firebase保存失敗時にisSyncedがfalseになりrethrowされる', () async {
      cacheManager.setLocalMode(false);
      final shop = createSampleShop(id: '0', name: 'デフォルト');
      final items = createSampleItems(1, shopId: '0');

      when(mockDataService.updateShop(
        any,
        isAnonymous: anyNamed('isAnonymous'),
      )).thenThrow(Exception('Firebase error'));

      expect(
        () => repository.persistReorderToFirebase(shop, items),
        throwsException,
      );
    });
  });

  group('deleteItem', () {
    test('アイテムがキャッシュから削除される', () async {
      final item = createSampleItem(id: 'item1', name: 'テスト');
      cacheManager.addItemToCache(item);

      await repository.deleteItem('item1');

      expect(cacheManager.items, isEmpty);
    });

    test('ショップからもアイテムが削除される', () async {
      final item = createSampleItem(id: 'item1', name: 'テスト', shopId: '0');
      cacheManager.addItemToCache(item);
      final shop = createSampleShop(id: '0', name: 'デフォルト', items: [item]);
      cacheManager.addShopToCache(shop);

      await repository.deleteItem('item1');

      expect(cacheManager.shops.first.items, isEmpty);
    });

    test('存在しないアイテムIDで例外がスローされる', () {
      expect(
        () => repository.deleteItem('non_existent_id'),
        throwsException,
      );
    });

    test('notifyListenersが呼ばれる', () async {
      final item = createSampleItem(id: 'item1', name: 'テスト');
      cacheManager.addItemToCache(item);

      await repository.deleteItem('item1');

      expect(notifyCount, greaterThan(0));
    });

    test('ローカルモードではFirebaseに保存されない', () async {
      final item = createSampleItem(id: 'item1', name: 'テスト');
      cacheManager.addItemToCache(item);

      await repository.deleteItem('item1');

      verifyNever(mockDataService.deleteItem(
        any,
        isAnonymous: anyNamed('isAnonymous'),
      ));
    });

    test('オンラインモードではFirebaseから削除される', () async {
      cacheManager.setLocalMode(false);
      final item = createSampleItem(id: 'item1', name: 'テスト');
      cacheManager.addItemToCache(item);

      when(mockDataService.deleteItem(
        any,
        isAnonymous: anyNamed('isAnonymous'),
      )).thenAnswer((_) async {});

      await repository.deleteItem('item1');

      verify(mockDataService.deleteItem(
        'item1',
        isAnonymous: anyNamed('isAnonymous'),
      )).called(1);
    });

    test('Firebase削除失敗時にキャッシュにロールバックされる', () async {
      cacheManager.setLocalMode(false);
      final item = createSampleItem(id: 'item1', name: 'テスト');
      cacheManager.addItemToCache(item);

      when(mockDataService.deleteItem(
        any,
        isAnonymous: anyNamed('isAnonymous'),
      )).thenThrow(Exception('Firebase error'));

      try {
        await repository.deleteItem('item1');
      } catch (_) {}

      expect(cacheManager.items.length, 1);
      expect(cacheManager.items.first.id, 'item1');
    });

    test('Firebase削除失敗時にショップにもロールバックされる', () async {
      cacheManager.setLocalMode(false);
      final item = createSampleItem(id: 'item1', name: 'テスト', shopId: '0');
      cacheManager.addItemToCache(item);
      final shop = createSampleShop(id: '0', name: 'デフォルト', items: [item]);
      cacheManager.addShopToCache(shop);

      when(mockDataService.deleteItem(
        any,
        isAnonymous: anyNamed('isAnonymous'),
      )).thenThrow(Exception('Firebase error'));

      try {
        await repository.deleteItem('item1');
      } catch (_) {}

      // ショップにアイテムが復元される
      expect(cacheManager.shops.first.items.length, 1);
    });
  });

  group('deleteItems（一括削除）', () {
    test('複数アイテムが一括削除される', () async {
      final items = createSampleItems(3, shopId: '0');
      for (final item in items) {
        cacheManager.addItemToCache(item);
      }

      final idsToDelete = items.map((item) => item.id).toList();
      await repository.deleteItems(idsToDelete);

      expect(cacheManager.items, isEmpty);
    });

    test('空のリストでは何も起きない', () async {
      final item = createSampleItem(id: 'item1', name: 'テスト');
      cacheManager.addItemToCache(item);

      await repository.deleteItems([]);

      expect(cacheManager.items.length, 1);
    });

    test('存在しないIDは無視される', () async {
      final item = createSampleItem(id: 'item1', name: 'テスト');
      cacheManager.addItemToCache(item);

      await repository.deleteItems(['non_existent_id']);

      // 存在しないIDのみなので何も削除されない
      expect(cacheManager.items.length, 1);
    });

    test('ショップからもアイテムが一括削除される', () async {
      final items = createSampleItems(3, shopId: '0');
      for (final item in items) {
        cacheManager.addItemToCache(item);
      }
      final shop = createSampleShop(id: '0', name: 'デフォルト', items: items);
      cacheManager.addShopToCache(shop);

      final idsToDelete = items.map((item) => item.id).toList();
      await repository.deleteItems(idsToDelete);

      expect(cacheManager.shops.first.items, isEmpty);
    });

    test('notifyListenersが呼ばれる', () async {
      final items = createSampleItems(2, shopId: '0');
      for (final item in items) {
        cacheManager.addItemToCache(item);
      }

      final idsToDelete = items.map((item) => item.id).toList();
      await repository.deleteItems(idsToDelete);

      expect(notifyCount, greaterThan(0));
    });

    test('オンラインモードではisBatchUpdatingフラグが管理される', () async {
      cacheManager.setLocalMode(false);
      final items = createSampleItems(2, shopId: '0');
      for (final item in items) {
        cacheManager.addItemToCache(item);
      }

      when(mockDataService.deleteItem(
        any,
        isAnonymous: anyNamed('isAnonymous'),
      )).thenAnswer((_) async {});

      final idsToDelete = items.map((item) => item.id).toList();
      await repository.deleteItems(idsToDelete);

      // 完了後はisBatchUpdatingがfalseに戻る
      expect(state.isBatchUpdating, false);
    });

    test('Firebase一括削除失敗時にロールバックされる', () async {
      cacheManager.setLocalMode(false);
      final items = createSampleItems(3, shopId: '0');
      for (final item in items) {
        cacheManager.addItemToCache(item);
      }

      when(mockDataService.deleteItem(
        any,
        isAnonymous: anyNamed('isAnonymous'),
      )).thenThrow(Exception('Firebase error'));

      final idsToDelete = items.map((item) => item.id).toList();

      try {
        await repository.deleteItems(idsToDelete);
      } catch (_) {}

      // ロールバック後にアイテムが復元される
      expect(cacheManager.items.length, 3);
    });

    test('Firebase一括削除失敗後にisBatchUpdatingがfalseに戻る', () async {
      cacheManager.setLocalMode(false);
      final items = createSampleItems(2, shopId: '0');
      for (final item in items) {
        cacheManager.addItemToCache(item);
      }

      when(mockDataService.deleteItem(
        any,
        isAnonymous: anyNamed('isAnonymous'),
      )).thenThrow(Exception('Firebase error'));

      final idsToDelete = items.map((item) => item.id).toList();

      try {
        await repository.deleteItems(idsToDelete);
      } catch (_) {}

      // finallyでisBatchUpdatingがfalseに戻る
      expect(state.isBatchUpdating, false);
    });
  });
}
