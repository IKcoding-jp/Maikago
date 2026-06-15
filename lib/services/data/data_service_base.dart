// DataServiceの共通基盤（Firebase接続・コレクション参照・匿名セッション管理）
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:uuid/uuid.dart';

/// DataService系クラスの共通基盤。
/// Firebase接続チェック・コレクション参照・匿名セッション管理を提供する。
class DataServiceBase {
  // NOTE: Firebase 依存をコンストラクタ初期化で参照すると
  // Firebase.initializeApp() 失敗時に即クラッシュするため、
  // 遅延ゲッターに変更して必要時のみ参照する。
  FirebaseFirestore get firestore => FirebaseFirestore.instance;
  FirebaseAuth get auth => FirebaseAuth.instance;
  static const String anonymousSessionKey = 'anonymous_session_id';

  /// Firebaseが利用可能かチェック
  bool get isFirebaseAvailable {
    try {
      // FirebaseCoreが初期化済みかを確認
      return Firebase.apps.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Firebase接続のタイムアウト付きチェック
  Future<bool> isFirebaseConnected() async {
    try {
      // 5秒でタイムアウト
      const timeout = Duration(seconds: 5);
      await firestore.waitForPendingWrites().timeout(timeout);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 匿名セッションIDを取得（未保存なら生成して保存）
  Future<String> getAnonymousSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    String? sessionId = prefs.getString(anonymousSessionKey);

    if (sessionId == null) {
      // 暗号的に安全なUUIDv4でセッションIDを生成
      sessionId = const Uuid().v4();
      await prefs.setString(anonymousSessionKey, sessionId);
    }

    return sessionId;
  }

  /// 認証ユーザーのアイテムコレクション参照
  CollectionReference<Map<String, dynamic>> get userItemsCollection {
    final user = auth.currentUser;
    if (user == null) throw Exception('ユーザーがログインしていません');
    return firestore.collection('users').doc(user.uid).collection('items');
  }

  /// 認証ユーザーのショップコレクション参照
  CollectionReference<Map<String, dynamic>> get userShopsCollection {
    final user = auth.currentUser;
    if (user == null) throw Exception('ユーザーがログインしていません');
    return firestore.collection('users').doc(user.uid).collection('shops');
  }

  /// 匿名セッションのアイテムコレクション参照
  Future<CollectionReference<Map<String, dynamic>>>
      get anonymousItemsCollection async {
    final sessionId = await getAnonymousSessionId();
    return firestore.collection('anonymous').doc(sessionId).collection('items');
  }

  /// 匿名セッションのショップコレクション参照
  Future<CollectionReference<Map<String, dynamic>>>
      get anonymousShopsCollection async {
    final sessionId = await getAnonymousSessionId();
    return firestore.collection('anonymous').doc(sessionId).collection('shops');
  }
}
