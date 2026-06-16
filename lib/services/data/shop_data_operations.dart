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
  /// 共有タブのグループ化・解除のように複数ドキュメントをまとめて更新する場合、
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

    // WriteBatch の上限は 500 操作。共有タブのグループは小規模だが、
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
        // 追加処理：このユーザーが削除したショップに関連する共有データを先に更新
        final user = auth.currentUser;
        try {
          final docData = doc.data();
          if (user != null) {
            // まず user shop ドキュメントに自動追加元の transmission ID があれば優先して処理
            final receivedFromTransmission =
                docData != null ? docData['receivedFromTransmission'] : null;
            if (receivedFromTransmission != null) {
              try {
                final tRef = firestore
                    .collection('transmissions')
                    .doc(receivedFromTransmission.toString());
                final tSnap = await tRef.get();
                if (tSnap.exists) {
                  final tData = tSnap.data()!;
                  final sharedWith = List<String>.from(
                    tData['sharedWith'] ?? [],
                  );
                  if (sharedWith.contains(user.uid)) {
                    sharedWith.remove(user.uid);
                    if (sharedWith.isEmpty) {
                      await tRef.update({
                        'isActive': false,
                        'status': 'deleted',
                        'deletedAt': DateTime.now().toIso8601String(),
                      });
                    } else {
                      await tRef.update({'sharedWith': sharedWith});
                    }
                  }
                }
              } catch (e) {
                DebugService().logError('共有データ更新エラー（transmission指定）: $e');
              }
            } else {
              // fallback: contentId に紐づく transmissions を検索してバッチ更新
              // セキュリティルール上、sharedWithに自分が含まれる条件が必要
              final query = await firestore
                  .collection('transmissions')
                  .where('contentId', isEqualTo: shopId)
                  .where('sharedWith', arrayContains: user.uid)
                  .get();

              final batch = firestore.batch();
              bool hasBatchWrites = false;
              for (final t in query.docs) {
                final data = t.data();
                final sharedWith = List<String>.from(data['sharedWith'] ?? []);
                if (sharedWith.contains(user.uid)) {
                  sharedWith.remove(user.uid);
                  if (sharedWith.isEmpty) {
                    batch.update(t.reference, {
                      'isActive': false,
                      'status': 'deleted',
                      'deletedAt': DateTime.now().toIso8601String(),
                    });
                  } else {
                    batch.update(t.reference, {'sharedWith': sharedWith});
                  }
                  hasBatchWrites = true;
                }
              }
              if (hasBatchWrites) {
                await batch.commit();
              }
            }
          }
        } catch (e) {
          DebugService().logError('共有データ更新エラー（ショップ削除前）: $e');
        }

        // マーカーを追加して、自動追加ロジックによる復元を防止
        try {
          if (user != null) {
            await firestore.collection('users').doc(user.uid).update({
              'deletedShopIds': FieldValue.arrayUnion([shopId]),
            });
          }
        } catch (e) {
          DebugService().logError('削除マーカー追加エラー: $e');
        }

        // 共有データの更新後にユーザーのショップを削除
        await docRef.delete();

        // NOTE: 削除マーカーはユーザーが明示的に削除したことを示すため
        // 自動復元を防止する目的で残す（以前はここでマーカーを削除していたが、それにより
        // リアルタイムの再追加が発生してしまっていたため保持するように変更）。
      } else {
        // ドキュメントが存在しない場合は成功として扱う
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
