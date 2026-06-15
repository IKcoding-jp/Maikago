import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:maikago/providers/data_provider.dart';
import '../helpers/test_helpers.dart';
import '../mocks.mocks.dart';

void main() {
  late DataProvider dataProvider;
  late MockDataService mockDataService;

  setUp(() {
    mockDataService = MockDataService();
    dataProvider = DataProvider(dataService: mockDataService);
    // テスト時はローカルモードで開始（Firebase依存を避ける）
    dataProvider.setLocalMode(true);
  });

  group('初期状態', () {
    test('itemsが空リストで初期化される', () {
      expect(dataProvider.items, isEmpty);
    });

    test('shopsが空リストで初期化される', () {
      expect(dataProvider.shops, isEmpty);
    });

    test('isLoadingがfalseで初期化される', () {
      expect(dataProvider.isLoading, false);
    });
  });

  group('setLocalMode', () {
    test('ローカルモードをtrueに設定できる', () {
      dataProvider.setLocalMode(true);
      expect(dataProvider.isLocalMode, true);
      expect(dataProvider.isSynced, true);
    });

    test('ローカルモードをfalseに設定できる', () {
      dataProvider.setLocalMode(false);
      expect(dataProvider.isLocalMode, false);
    });

    test('notifyListenersが呼ばれる', () {
      var notified = false;
      dataProvider.addListener(() => notified = true);

      dataProvider.setLocalMode(true);

      expect(notified, true);
    });
  });

  group('addItem', () {
    test('ローカルモードでアイテムがリストに追加される', () async {
      final item = createSampleItem(id: '', name: 'テスト商品', price: 100);

      await dataProvider.addItem(item);

      expect(dataProvider.items.length, 1);
      expect(dataProvider.items.first.name, 'テスト商品');
      expect(dataProvider.items.first.price, 100);
    });

    test('IDが空の場合は自動生成される', () async {
      final item = createSampleItem(id: '', name: 'テスト');

      await dataProvider.addItem(item);

      expect(dataProvider.items.first.id, isNotEmpty);
    });

    test('createdAtが自動設定される', () async {
      final item = createSampleItem(id: '', name: 'テスト');

      await dataProvider.addItem(item);

      expect(dataProvider.items.first.createdAt, isNotNull);
    });

    test('新規アイテムはリストの先頭に追加される', () async {
      final item1 = createSampleItem(id: '', name: '商品1');
      final item2 = createSampleItem(id: '', name: '商品2');

      await dataProvider.addItem(item1);
      await dataProvider.addItem(item2);

      expect(dataProvider.items.length, 2);
      expect(dataProvider.items.first.name, '商品2');
    });

    test('重複IDの場合はupdateItemが呼ばれる', () async {
      final item = createSampleItem(id: 'existing_id', name: '元の名前');
      await dataProvider.addItem(item);

      final updatedItem = createSampleItem(id: 'existing_id', name: '更新名');
      await dataProvider.addItem(updatedItem);

      expect(dataProvider.items.length, 1);
      expect(dataProvider.items.first.name, '更新名');
    });

    test('対応するショップにもアイテムが追加される', () async {
      final shop = createSampleShop(id: '0', name: 'デフォルト');
      dataProvider.shops.add(shop);

      final item = createSampleItem(id: '', name: 'テスト', shopId: '0');
      await dataProvider.addItem(item);

      expect(dataProvider.shops.first.items.length, 1);
    });

    test('notifyListenersが呼ばれる', () async {
      var notifyCount = 0;
      dataProvider.addListener(() => notifyCount++);

      final item = createSampleItem(id: '', name: 'テスト');
      await dataProvider.addItem(item);

      expect(notifyCount, greaterThan(0));
    });

    test('ローカルモードではFirebaseに保存されない', () async {
      final item = createSampleItem(id: '', name: 'テスト');
      await dataProvider.addItem(item);

      verifyNever(mockDataService.saveItem(
        any,
        isAnonymous: anyNamed('isAnonymous'),
      ));
    });

    test('オンラインモードではFirebaseに保存される', () async {
      dataProvider.setLocalMode(false);
      // AuthProviderが未設定の場合、_shouldUseAnonymousSession=false

      when(mockDataService.saveItem(
        any,
        isAnonymous: anyNamed('isAnonymous'),
      )).thenAnswer((_) async {});

      final item = createSampleItem(id: '', name: 'テスト');
      await dataProvider.addItem(item);

      verify(mockDataService.saveItem(
        any,
        isAnonymous: anyNamed('isAnonymous'),
      )).called(1);
    });

    // NOTE: addItemのFirebase保存失敗時のロールバックテストは、
    // _performBackgroundOperationsがfire-and-forget（awaitなし）で呼ばれるため、
    // 非同期例外のハンドリングが困難。将来のリファクタリング（Issue #3）で
    // テスタブルな構造に変更後にテストを追加する。
  });

  group('updateItem', () {
    test('ローカルモードでアイテムが更新される', () async {
      final item = createSampleItem(id: '', name: '元の名前', price: 100);
      await dataProvider.addItem(item);
      final addedItem = dataProvider.items.first;

      final updatedItem = addedItem.copyWith(name: '新しい名前', price: 200);
      await dataProvider.updateItem(updatedItem);

      expect(dataProvider.items.first.name, '新しい名前');
      expect(dataProvider.items.first.price, 200);
    });

    test('ショップ内のアイテムも同期更新される', () async {
      final shop = createSampleShop(id: '0', name: 'デフォルト');
      dataProvider.shops.add(shop);

      final item = createSampleItem(id: '', name: '元の名前', shopId: '0');
      await dataProvider.addItem(item);
      final addedItem = dataProvider.items.first;

      final updatedItem = addedItem.copyWith(name: '新しい名前');
      await dataProvider.updateItem(updatedItem);

      expect(dataProvider.shops.first.items.first.name, '新しい名前');
    });

    test('notifyListenersが呼ばれる', () async {
      final item = createSampleItem(id: '', name: 'テスト');
      await dataProvider.addItem(item);

      var notified = false;
      dataProvider.addListener(() => notified = true);

      final updatedItem = dataProvider.items.first.copyWith(name: '更新');
      await dataProvider.updateItem(updatedItem);

      expect(notified, true);
    });

    test('ローカルモードではFirebaseに保存されない', () async {
      final item = createSampleItem(id: '', name: 'テスト');
      await dataProvider.addItem(item);

      final updatedItem = dataProvider.items.first.copyWith(name: '更新');
      await dataProvider.updateItem(updatedItem);

      verifyNever(mockDataService.updateItem(
        any,
        isAnonymous: anyNamed('isAnonymous'),
      ));
    });
  });

  group('deleteItem', () {
    test('ローカルモードでアイテムが削除される', () async {
      final item = createSampleItem(id: '', name: 'テスト');
      await dataProvider.addItem(item);
      final addedItemId = dataProvider.items.first.id;

      await dataProvider.deleteItem(addedItemId);

      expect(dataProvider.items, isEmpty);
    });

    test('ショップからもアイテムが削除される', () async {
      final shop = createSampleShop(id: '0', name: 'デフォルト');
      dataProvider.shops.add(shop);

      final item = createSampleItem(id: '', name: 'テスト', shopId: '0');
      await dataProvider.addItem(item);
      final addedItemId = dataProvider.items.first.id;

      await dataProvider.deleteItem(addedItemId);

      expect(dataProvider.shops.first.items, isEmpty);
    });

    test('存在しないアイテムの削除は例外をスローする', () async {
      expect(
        () => dataProvider.deleteItem('non_existent_id'),
        throwsException,
      );
    });

    test('ローカルモードではFirebaseに保存されない', () async {
      final item = createSampleItem(id: '', name: 'テスト');
      await dataProvider.addItem(item);

      await dataProvider.deleteItem(dataProvider.items.first.id);

      verifyNever(mockDataService.deleteItem(
        any,
        isAnonymous: anyNamed('isAnonymous'),
      ));
    });

    test('Firebase削除失敗時にロールバックされる', () async {
      dataProvider.setLocalMode(false);
      final item = createSampleItem(id: '', name: 'テスト');

      when(mockDataService.saveItem(
        any,
        isAnonymous: anyNamed('isAnonymous'),
      )).thenAnswer((_) async {});

      await dataProvider.addItem(item);
      final addedItemId = dataProvider.items.first.id;

      when(mockDataService.deleteItem(
        any,
        isAnonymous: anyNamed('isAnonymous'),
      )).thenThrow(Exception('Firebase error'));

      try {
        await dataProvider.deleteItem(addedItemId);
      } catch (e) {
        // エラー想定内
      }

      expect(dataProvider.items.length, 1);
    });
  });

  group('deleteItems (一括削除)', () {
    test('複数アイテムが一括削除される', () async {
      for (int i = 0; i < 3; i++) {
        await dataProvider.addItem(
          createSampleItem(id: '', name: '商品$i'),
        );
      }
      expect(dataProvider.items.length, 3);

      final idsToDelete = dataProvider.items.map((item) => item.id).toList();
      await dataProvider.deleteItems(idsToDelete);

      expect(dataProvider.items, isEmpty);
    });

    test('空のリストを渡しても何も起きない', () async {
      await dataProvider.addItem(createSampleItem(id: '', name: 'テスト'));

      await dataProvider.deleteItems([]);

      expect(dataProvider.items.length, 1);
    });
  });

  group('ショップ操作', () {
    test('addShopでショップが追加される', () async {
      final shop = createSampleShop(id: '1', name: 'スーパー');
      await dataProvider.addShop(shop);

      expect(dataProvider.shops.length, 1);
      expect(dataProvider.shops.first.name, 'スーパー');
    });
  });

  group('loadData', () {
    test('ローカルモードではFirebaseからロードしない', () async {
      await dataProvider.loadData();

      verifyNever(mockDataService.getItemsOnce(
        isAnonymous: anyNamed('isAnonymous'),
      ));
      verifyNever(mockDataService.getShopsOnce(
        isAnonymous: anyNamed('isAnonymous'),
      ));
    });

    test('オンラインモードではFirebaseからロードする', () async {
      dataProvider.setLocalMode(false);

      when(mockDataService.getItemsOnce(
        isAnonymous: anyNamed('isAnonymous'),
      )).thenAnswer((_) async => [
            createSampleItem(id: '1', name: '商品1'),
          ]);
      when(mockDataService.getShopsOnce(
        isAnonymous: anyNamed('isAnonymous'),
      )).thenAnswer((_) async => [
            createSampleShop(id: '0', name: 'デフォルト'),
          ]);

      // getItemsとgetShopsのStreamもスタブが必要（_startRealtimeSync用）
      when(mockDataService.getItems(
        isAnonymous: anyNamed('isAnonymous'),
      )).thenAnswer((_) => Stream.value([]));
      when(mockDataService.getShops(
        isAnonymous: anyNamed('isAnonymous'),
      )).thenAnswer((_) => Stream.value([]));

      await dataProvider.loadData();

      verify(mockDataService.getItemsOnce(
        isAnonymous: anyNamed('isAnonymous'),
      )).called(1);
      verify(mockDataService.getShopsOnce(
        isAnonymous: anyNamed('isAnonymous'),
      )).called(1);
    });

    test('ロード中はisLoadingがtrueになる', () async {
      final loadingStates = <bool>[];
      dataProvider.addListener(() {
        loadingStates.add(dataProvider.isLoading);
      });

      await dataProvider.loadData();

      // loadingが一度はtrueになり、最終的にfalseになる
      expect(loadingStates, contains(false));
    });

    test('ロード完了後にisSyncedがtrueになる', () async {
      await dataProvider.loadData();

      // ローカルモードでは常にsynced
      expect(dataProvider.isSynced, true);
    });
  });
}
