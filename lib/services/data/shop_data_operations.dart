// Shop関連のFirestore CRUD操作
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async'; // TimeoutException用
import 'package:maikago/models/shop.dart';
import 'package:maikago/services/debug_service.dart';
import 'package:maikago/utils/exceptions.dart';
import 'package:maikago/services/data/data_service_base.dart';

/// Shop（ショップ）に対するCRUD操作を提供するmixin。
/// [DataServiceBase] を継承したクラスでのみ使用可能。
mixin ShopDataOperations on DataServiceBase {
  /// ショップを保存
  Future<void> saveShop(Shop shop, {bool isAnonymous = false}) async {
    // Firebaseが利用できない場合はスキップ
    if (!isFirebaseAvailable) return;

    try {
      if (isAnonymous) {
        final collection = await anonymousShopsCollection;
        await collection.doc(shop.id).set(shop.toMap());
      } else {
        final user = auth.currentUser;
        if (user == null) throw Exception('ユーザーがログインしていません');
        await userShopsCollection.doc(shop.id).set(shop.toMap());
      }
    } catch (e) {
      if (e.toString().contains('permission-denied')) {
        throw const PermissionDeniedError(
            'Firebaseの権限エラーです。セキュリティルールを確認してください。');
      }
      rethrow;
    }
  }

  /// ショップを更新（存在しない場合は作成）
  Future<void> updateShop(Shop shop, {bool isAnonymous = false}) async {
    // Firebaseが利用できない場合はスキップ
    if (!isFirebaseAvailable) return;

    CollectionReference<Map<String, dynamic>> collection;

    if (isAnonymous) {
      collection = await anonymousShopsCollection;
    } else {
      collection = userShopsCollection;
    }

    // null値を明示的に削除するためにFieldValue.delete()を使用
    final updateData = <String, dynamic>{};
    final shopMap = shop.toMap();
    shopMap.forEach((key, value) {
      if (value == null) {
        updateData[key] = FieldValue.delete();
      } else {
        updateData[key] = value;
      }
    });

    // set(merge: true) で存在確認不要（存在すれば更新、なければ作成）
    await collection.doc(shop.id).set(updateData, SetOptions(merge: true));
  }

  /// 複数ショップを WriteBatch で一括更新する（Issue #159）。
  ///
  /// 同期タブのグループ化・解除のように複数ドキュメントをまとめて更新する場合、
  /// 順次 `await updateShop()` だと途中失敗で「一部だけ書き込まれた」中途半端な
  /// 状態が残る。WriteBatch なら **全件成功 or 全件失敗** が Firestore 側で保証される。
  ///
  /// 既存 [updateShop] と同じく null 値は [FieldValue.delete] に変換し、
  /// `set(merge: true)` で「存在すれば更新、なければ作成」とする。
  Future<void> updateShopsBatch(
    List<Shop> shops, {
    bool isAnonymous = false,
  }) async {
    // Firebaseが利用できない場合はスキップ
    if (!isFirebaseAvailable) return;
    if (shops.isEmpty) return;

    CollectionReference<Map<String, dynamic>> collection;
    if (isAnonymous) {
      collection = await anonymousShopsCollection;
    } else {
      collection = userShopsCollection;
    }

    // WriteBatch の上限は 500 操作。同期タブのグループは小規模だが、
    // 念のため 500 件ごとに分割してコミットする。
    const int batchLimit = 500;
    try {
      for (var start = 0; start < shops.length; start += batchLimit) {
        final end = (start + batchLimit < shops.length)
            ? start + batchLimit
            : shops.length;
        final chunk = shops.sublist(start, end);

        final batch = firestore.batch();
        for (final shop in chunk) {
          // null値を明示的に削除するためにFieldValue.delete()を使用
          final updateData = <String, dynamic>{};
          final shopMap = shop.toMap();
          shopMap.forEach((key, value) {
            if (value == null) {
              updateData[key] = FieldValue.delete();
            } else {
              updateData[key] = value;
            }
          });
          batch.set(
            collection.doc(shop.id),
            updateData,
            SetOptions(merge: true),
          );
        }
        await batch.commit();
      }
    } catch (e) {
      if (e.toString().contains('permission-denied')) {
        throw const PermissionDeniedError(
            'Firebaseの権限エラーです。セキュリティルールを確認してください。');
      }
      rethrow;
    }
  }

  /// ショップを削除（存在しない場合は何もしない）
  Future<void> deleteShop(String shopId, {bool isAnonymous = false}) async {
    // Firebaseが利用できない場合はスキップ
    if (!isFirebaseAvailable) return;

    try {
      CollectionReference<Map<String, dynamic>> collection;

      if (isAnonymous) {
        collection = await anonymousShopsCollection;
      } else {
        collection = userShopsCollection;
      }

      // まずドキュメントが存在するかチェック
      final docRef = collection.doc(shopId);
      final doc = await docRef.get();

      if (doc.exists) {
        final user = auth.currentUser;

        // マーカーを追加して、ユーザーが明示的に削除したショップの自動復元を防止する。
        try {
          if (user != null) {
            await firestore.collection('users').doc(user.uid).update({
              'deletedShopIds': FieldValue.arrayUnion([shopId]),
            });
          }
        } catch (e) {
          DebugService().logError('削除マーカー追加エラー: $e');
        }

        // ユーザーのショップを削除
        await docRef.delete();
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Firestore ドキュメントを安全に [Shop] へ変換する（Issue #164）。
  ///
  /// 壊れたドキュメント1件で一覧全体を道連れにしないため、復元に失敗した
  /// ドキュメントはログを残して null を返し、呼び出し側でスキップする。
  Shop? _shopFromDocSafe(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    try {
      final data = doc.data();
      data['id'] = doc.id;
      return Shop.fromMap(data);
    } catch (e) {
      DebugService().logError('ショップ復元エラー（スキップ） id=${doc.id}: $e');
      return null;
    }
  }

  /// すべてのショップを取得（リアルタイム購読）
  Stream<List<Shop>> getShops({bool isAnonymous = false}) {
    // Firebaseが利用できない場合は空のストリームを返す
    if (!isFirebaseAvailable) return Stream.value([]);

    if (isAnonymous) {
      return Stream.fromFuture(anonymousShopsCollection).asyncExpand(
        (collection) => collection
            .orderBy('createdAt', descending: true)
            .snapshots()
            .map((snapshot) {
          return snapshot.docs.map(_shopFromDocSafe).whereType<Shop>().toList();
        }),
      );
    } else {
      return userShopsCollection
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map(_shopFromDocSafe).whereType<Shop>().toList();
      });
    }
  }

  /// すべてのショップを取得（一度だけ）
  Future<List<Shop>> getShopsOnce({bool isAnonymous = false}) async {
    // Firebaseが利用できない場合は空のリストを返す
    if (!isFirebaseAvailable) return [];

    try {
      // Firebase接続をチェック（タイムアウト付き）
      final isConnected = await isFirebaseConnected();
      if (!isConnected) return [];

      CollectionReference<Map<String, dynamic>> collection;

      if (isAnonymous) {
        collection = await anonymousShopsCollection;
      } else {
        collection = userShopsCollection;
      }

      // 10秒でタイムアウト
      final snapshot = await collection.get().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException(
              'ショップ取得がタイムアウトしました', const Duration(seconds: 10));
        },
      );

      // 重複を除去するためのマップ
      final Map<String, Shop> uniqueShopsMap = {};

      for (final doc in snapshot.docs) {
        final shop = _shopFromDocSafe(doc);
        // 壊れたドキュメントはスキップし、他のショップは読み込む（Issue #164）
        if (shop == null) continue;

        // 同じIDのショップが既に存在する場合は、より新しい方を保持
        if (uniqueShopsMap.containsKey(shop.id)) {
          final existingShop = uniqueShopsMap[shop.id]!;
          final shopCreatedAt = shop.createdAt ?? DateTime.now();
          final existingCreatedAt = existingShop.createdAt ?? DateTime.now();

          if (shopCreatedAt.isAfter(existingCreatedAt)) {
            uniqueShopsMap[shop.id] = shop;
          }
        } else {
          uniqueShopsMap[shop.id] = shop;
        }
      }

      final shops = uniqueShopsMap.values.toList();
      return shops;
    } catch (e) {
      DebugService().logError('ショップ取得エラー: $e');
      // エラーが発生しても空のリストを返してアプリを継続
      return [];
    }
  }
}
