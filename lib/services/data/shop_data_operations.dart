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
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return Shop.fromMap(data);
          }).toList();
        }),
      );
    } else {
      return userShopsCollection
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return Shop.fromMap(data);
        }).toList();
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
        final data = doc.data();
        data['id'] = doc.id;
        final shop = Shop.fromMap(data);

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
