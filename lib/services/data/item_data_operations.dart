// Item関連のFirestore CRUD操作
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async'; // TimeoutException用
import 'package:maikago/models/list.dart';
import 'package:maikago/services/debug_service.dart';
import 'package:maikago/utils/exceptions.dart';
import 'package:maikago/services/data/data_service_base.dart';

/// Item（リスト項目）に対するCRUD操作を提供するmixin。
/// [DataServiceBase] を継承したクラスでのみ使用可能。
mixin ItemDataOperations on DataServiceBase {
  /// リストを保存（認証ユーザー/匿名セッションを切り替え）
  Future<void> saveItem(ListItem item, {bool isAnonymous = false}) async {
    // Firebaseが利用できない場合はスキップ
    if (!isFirebaseAvailable) return;

    try {
      if (isAnonymous) {
        final collection = await anonymousItemsCollection;
        await collection.doc(item.id).set(item.toMap());
      } else {
        final user = auth.currentUser;
        if (user == null) throw Exception('ユーザーがログインしていません');
        await userItemsCollection.doc(item.id).set(item.toMap());
      }
    } catch (e) {
      if (e.toString().contains('permission-denied')) {
        throw const PermissionDeniedError(
            'Firebaseの権限エラーです。セキュリティルールを確認してください。');
      }
      rethrow;
    }
  }

  /// リストを更新（存在しない場合は作成）
  Future<void> updateItem(ListItem item, {bool isAnonymous = false}) async {
    // Firebaseが利用できない場合はスキップ
    if (!isFirebaseAvailable) return;

    CollectionReference<Map<String, dynamic>> collection;

    if (isAnonymous) {
      collection = await anonymousItemsCollection;
    } else {
      collection = userItemsCollection;
    }

    // set(merge: true) で存在確認不要（存在すれば更新、なければ作成）
    await collection.doc(item.id).set(item.toMap(), SetOptions(merge: true));
  }

  /// リストを削除（存在しない場合は何もしない）
  Future<void> deleteItem(String itemId, {bool isAnonymous = false}) async {
    // Firebaseが利用できない場合はスキップ
    if (!isFirebaseAvailable) return;

    CollectionReference<Map<String, dynamic>> collection;

    if (isAnonymous) {
      collection = await anonymousItemsCollection;
    } else {
      collection = userItemsCollection;
    }

    // Firestoreは存在しないドキュメントの削除でもエラーにならない
    await collection.doc(itemId).delete();
  }

  /// Firestore ドキュメントを安全に [ListItem] へ変換する（Issue #164）。
  ///
  /// 壊れたドキュメント1件で一覧全体を道連れにしないため、復元に失敗した
  /// ドキュメントはログを残して null を返し、呼び出し側でスキップする。
  ListItem? _itemFromDocSafe(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    try {
      final data = doc.data();
      data['id'] = doc.id;
      return ListItem.fromMap(data);
    } catch (e) {
      DebugService().logError('アイテム復元エラー（スキップ） id=${doc.id}: $e');
      return null;
    }
  }

  /// すべてのリストを取得（リアルタイム購読）
  Stream<List<ListItem>> getItems({bool isAnonymous = false}) {
    // Firebaseが利用できない場合は空のストリームを返す
    if (!isFirebaseAvailable) return Stream.value([]);

    if (isAnonymous) {
      // 匿名セッションIDのFutureからStreamを作成し、その後snapshotsに展開
      return Stream.fromFuture(anonymousItemsCollection).asyncExpand(
        (collection) => collection
            .orderBy('createdAt', descending: true)
            .snapshots()
            .map((snapshot) {
          return snapshot.docs
              .map(_itemFromDocSafe)
              .whereType<ListItem>()
              .toList();
        }),
      );
    } else {
      return userItemsCollection
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map(_itemFromDocSafe)
            .whereType<ListItem>()
            .toList();
      });
    }
  }

  /// すべてのリストを取得（一度だけ）
  Future<List<ListItem>> getItemsOnce({bool isAnonymous = false}) async {
    // Firebaseが利用できない場合は空のリストを返す
    if (!isFirebaseAvailable) return [];

    try {
      // Firebase接続をチェック（タイムアウト付き）
      final isConnected = await isFirebaseConnected();
      if (!isConnected) return [];

      CollectionReference<Map<String, dynamic>> collection;

      if (isAnonymous) {
        collection = await anonymousItemsCollection;
      } else {
        collection = userItemsCollection;
      }

      // 10秒でタイムアウト
      final snapshot = await collection.get().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException(
              'アイテム取得がタイムアウトしました', const Duration(seconds: 10));
        },
      );

      // 重複を除去するためのマップ
      final Map<String, ListItem> uniqueItemsMap = {};

      for (final doc in snapshot.docs) {
        final item = _itemFromDocSafe(doc);
        // 壊れたドキュメントはスキップし、他のアイテムは読み込む（Issue #164）
        if (item == null) continue;

        // 同じIDのアイテムが既に存在する場合は、より新しい方を保持
        if (uniqueItemsMap.containsKey(item.id)) {
          final existingItem = uniqueItemsMap[item.id]!;
          final itemCreatedAt = item.createdAt ?? DateTime.now();
          final existingCreatedAt = existingItem.createdAt ?? DateTime.now();

          if (itemCreatedAt.isAfter(existingCreatedAt)) {
            uniqueItemsMap[item.id] = item;
          }
        } else {
          uniqueItemsMap[item.id] = item;
        }
      }

      final items = uniqueItemsMap.values.toList();
      return items;
    } catch (e) {
      DebugService().logError('リスト取得エラー: $e');
      // エラーが発生しても空のリストを返してアプリを継続
      return [];
    }
  }
}
