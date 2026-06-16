import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:maikago/models/shop.dart';
import 'package:maikago/models/list.dart';
import 'package:maikago/providers/data_provider.dart';
import 'package:maikago/services/settings_persistence.dart';
import '../helpers/test_helpers.dart';
import '../mocks.mocks.dart';

/// Issue #154: ゲスト→ログイン移行の失敗時にローカルデータが永久消失する問題の
/// 再発防止テスト。
///
/// 検証する不変条件:
/// - 一部でも保存に失敗したらローカル（ゲスト）データを消さない
/// - 再ログイン（再試行）で同じショップ/アイテムを重複作成しない
/// - 全件成功したときだけゲストデータと移行進捗をクリアする
///
/// 移行対象は SharedPreferences のゲストデータ（guest_shops / guest_items）を正とする。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DataProvider dataProvider;
  late MockDataService mockDataService;

  // 2ショップ・2アイテムのゲストデータを SharedPreferences に保存した状態を作る
  void seedGuestStorageWithTwoShops() {
    final shopA = createSampleShop(id: 'shopA', name: 'ショップA');
    final shopB = createSampleShop(id: 'shopB', name: 'ショップB');
    final itemA1 =
        createSampleItem(id: 'itemA1', name: '商品A1', shopId: 'shopA');
    final itemB1 =
        createSampleItem(id: 'itemB1', name: '商品B1', shopId: 'shopB');

    SharedPreferences.setMockInitialValues({
      'is_guest_mode': true,
      'guest_shops': jsonEncode([shopA.toMap(), shopB.toMap()]),
      'guest_items': jsonEncode([itemA1.toMap(), itemB1.toMap()]),
    });
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockDataService = MockDataService();
    dataProvider = DataProvider(dataService: mockDataService);
    dataProvider.setLocalMode(true);
  });

  group('migrateGuestDataToCloud - 全件成功', () {
    test('全件成功時にゲストデータと移行進捗がクリアされる', () async {
      seedGuestStorageWithTwoShops();

      when(mockDataService.saveShop(any, isAnonymous: anyNamed('isAnonymous')))
          .thenAnswer((_) async {});
      when(mockDataService.saveItem(any, isAnonymous: anyNamed('isAnonymous')))
          .thenAnswer((_) async {});

      final result = await dataProvider.migrateGuestDataToCloud();

      expect(result.isComplete, isTrue);
      expect(result.hasFailures, isFalse);
      expect(result.migratedShops, 2);
      expect(result.migratedItems, 2);

      // 全件成功 → ゲストデータは消えてよい
      expect(await SettingsPersistence.loadGuestItems(), isNull);
      expect(await SettingsPersistence.loadGuestShops(), isNull);
      expect(await SettingsPersistence.loadGuestMode(), isFalse);

      // 移行進捗もクリアされる
      final (shopMap, itemIds) =
          await SettingsPersistence.loadMigrationProgress();
      expect(shopMap, isEmpty);
      expect(itemIds, isEmpty);
    });
  });

  group('migrateGuestDataToCloud - 一部失敗（データを消さない）', () {
    test('ショップ保存が一部失敗するとゲストデータが残る', () async {
      seedGuestStorageWithTwoShops();

      // shopB の保存だけ失敗させる（ネットワーク遮断を模擬）
      when(mockDataService.saveShop(any, isAnonymous: anyNamed('isAnonymous')))
          .thenAnswer((invocation) async {
        final shop = invocation.positionalArguments[0] as Shop;
        if (shop.name == 'ショップB') {
          throw Exception('network error');
        }
      });
      when(mockDataService.saveItem(any, isAnonymous: anyNamed('isAnonymous')))
          .thenAnswer((_) async {});

      final result = await dataProvider.migrateGuestDataToCloud();

      expect(result.hasFailures, isTrue);
      expect(result.failedShops, 1);
      expect(result.failedItems, 1); // shopB 配下の商品B1も保存できていない

      // ★最重要: 一部失敗時はゲストデータが残る（永久消失しない）
      expect(await SettingsPersistence.loadGuestItems(), isNotNull);
      expect(await SettingsPersistence.loadGuestShops(), isNotNull);
      expect(await SettingsPersistence.loadGuestMode(), isTrue);

      // 成功した shopA は進捗に記録され、次回再試行時にスキップできる
      final (shopMap, itemIds) =
          await SettingsPersistence.loadMigrationProgress();
      expect(shopMap.containsKey('shopA'), isTrue);
      expect(shopMap.containsKey('shopB'), isFalse);
      expect(itemIds.contains('itemA1'), isTrue);
    });

    test('アイテム保存が失敗してもゲストデータが残る', () async {
      seedGuestStorageWithTwoShops();

      when(mockDataService.saveShop(any, isAnonymous: anyNamed('isAnonymous')))
          .thenAnswer((_) async {});
      // 全アイテムの保存を失敗させる
      when(mockDataService.saveItem(any, isAnonymous: anyNamed('isAnonymous')))
          .thenThrow(Exception('network error'));

      final result = await dataProvider.migrateGuestDataToCloud();

      expect(result.hasFailures, isTrue);
      expect(result.failedItems, 2);

      // アイテムが1件でも保存できていなければゲストデータは残す
      expect(await SettingsPersistence.loadGuestItems(), isNotNull);
      expect(await SettingsPersistence.loadGuestShops(), isNotNull);
    });
  });

  group('migrateGuestDataToCloud - 冪等性（再ログインで重複しない）', () {
    test('再試行時に成功済みのショップ/アイテムを重複作成しない', () async {
      seedGuestStorageWithTwoShops();

      var shopBShouldFail = true;
      when(mockDataService.saveShop(any, isAnonymous: anyNamed('isAnonymous')))
          .thenAnswer((invocation) async {
        final shop = invocation.positionalArguments[0] as Shop;
        if (shop.name == 'ショップB' && shopBShouldFail) {
          throw Exception('network error');
        }
      });
      when(mockDataService.saveItem(any, isAnonymous: anyNamed('isAnonymous')))
          .thenAnswer((_) async {});

      // 1回目: shopB が失敗 → 一部失敗
      final firstResult = await dataProvider.migrateGuestDataToCloud();
      expect(firstResult.hasFailures, isTrue);

      // 2回目（再ログイン相当）: ネットワーク回復で shopB も成功
      shopBShouldFail = false;
      final secondResult = await dataProvider.retryPendingGuestMigration();
      expect(secondResult.isComplete, isTrue);

      // saveShop の全呼び出しを検証: shopA は1回だけ（重複なし）、shopB は2回（失敗→再試行）
      final capturedShops = verify(
        mockDataService.saveShop(
          captureAny,
          isAnonymous: anyNamed('isAnonymous'),
        ),
      ).captured.cast<Shop>();
      final shopACalls = capturedShops.where((s) => s.name == 'ショップA').length;
      final shopBCalls = capturedShops.where((s) => s.name == 'ショップB').length;
      expect(shopACalls, 1, reason: '成功済みショップAを再保存してはいけない');
      expect(shopBCalls, 2, reason: '失敗したショップBのみ再試行する');

      // 全件成功 → ゲストデータと進捗がクリアされる
      expect(await SettingsPersistence.loadGuestItems(), isNull);
      final (shopMap, itemIds) =
          await SettingsPersistence.loadMigrationProgress();
      expect(shopMap, isEmpty);
      expect(itemIds, isEmpty);
    });
  });

  group('migrateGuestDataToCloud - orphanアイテム（永久スタック防止）', () {
    test('属するショップが存在しないorphanアイテムも移行され、完了できる', () async {
      // shopA は存在するが、deletedShop は存在しない（ショップ削除後に残ったアイテムを模擬）
      final shopA = createSampleShop(id: 'shopA', name: 'ショップA');
      final itemA1 =
          createSampleItem(id: 'itemA1', name: '商品A1', shopId: 'shopA');
      final orphan =
          createSampleItem(id: 'orphan1', name: '孤立商品', shopId: 'deletedShop');

      SharedPreferences.setMockInitialValues({
        'is_guest_mode': true,
        'guest_shops': jsonEncode([shopA.toMap()]),
        'guest_items': jsonEncode([itemA1.toMap(), orphan.toMap()]),
      });

      when(mockDataService.saveShop(any, isAnonymous: anyNamed('isAnonymous')))
          .thenAnswer((_) async {});
      when(mockDataService.saveItem(any, isAnonymous: anyNamed('isAnonymous')))
          .thenAnswer((_) async {});

      final result = await dataProvider.migrateGuestDataToCloud();

      // orphan を取りこぼさず全件成功でき、毎回警告が出続けるスタックに陥らない
      expect(result.isComplete, isTrue, reason: 'orphanアイテムで永久未完了になってはいけない');
      expect(result.migratedItems, 2);

      // orphan は元の shopId を保ったまま保存される（ローカル状態を忠実に保持）
      final savedItems = verify(
        mockDataService.saveItem(captureAny,
            isAnonymous: anyNamed('isAnonymous')),
      ).captured.cast<ListItem>();
      final savedOrphan = savedItems.firstWhere((i) => i.id == 'orphan1');
      expect(savedOrphan.shopId, 'deletedShop');

      // 全件成功 → ゲストデータがクリアされる
      expect(await SettingsPersistence.loadGuestItems(), isNull);
    });
  });

  group('migrateGuestDataToCloud - 対象なし', () {
    test('ゲストデータが空なら何もしない', () async {
      SharedPreferences.setMockInitialValues({});

      final result = await dataProvider.migrateGuestDataToCloud();

      expect(result.isNothingToMigrate, isTrue);
      verifyNever(
          mockDataService.saveShop(any, isAnonymous: anyNamed('isAnonymous')));
    });
  });
}
