// Firebase 認証と Google Sign-In を使ったログイン/ログアウトを提供
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:maikago/env.dart';
import 'package:maikago/services/web_utils.dart'
    if (dart.library.html) 'web_utils_web.dart';
import 'package:maikago/services/debug_service.dart';

/// 認証関連のユースケースを集約したサービス。
/// - Google でのサインイン
/// - 認証状態監視
/// - サインアウト
class AuthService {
  /// Firebase 認証のシングルトン
  FirebaseAuth get _auth {
    if (Firebase.apps.isEmpty) {
      throw StateError('Firebase is not initialized');
    }
    return FirebaseAuth.instance;
  }

  /// Google サインインのシングルトン（v7 API）
  GoogleSignIn get _googleSignIn => GoogleSignIn.instance;

  /// GoogleSignIn初期化済みフラグ
  bool _googleSignInInitialized = false;

  /// GoogleSignInの初期化（v7で必須）
  Future<void> _ensureGoogleSignInInitialized() async {
    if (_googleSignInInitialized) return;

    final serverClientId = Env.googleWebClientId;
    if (serverClientId.isEmpty) {
      DebugService()
          .logWarning('GOOGLE_WEB_CLIENT_ID が未設定です。idTokenが取得できない可能性があります。');
    }

    await _googleSignIn.initialize(
      serverClientId: serverClientId.isNotEmpty ? serverClientId : null,
    );
    _googleSignInInitialized = true;
  }

  /// 現在のユーザーを取得
  User? get currentUser {
    try {
      if (Firebase.apps.isEmpty) return null;
      return _auth.currentUser;
    } catch (e) {
      DebugService().logError('Firebase認証エラー: $e');
      return null;
    }
  }

  /// 認証状態の変更を監視するストリーム
  Stream<User?> get authStateChanges {
    try {
      if (Firebase.apps.isEmpty) return Stream.value(null);
      return _auth.authStateChanges();
    } catch (e) {
      DebugService().logError('Firebase認証ストリームエラー: $e');
      // エラー時は空のストリームを返す
      return Stream.value(null);
    }
  }

  /// Webでリダイレクト認証の結果を確認（アプリ起動時に呼び出す）
  Future<void> checkRedirectResult() async {
    if (!kIsWeb) return;

    try {
      final userCredential = await _auth.getRedirectResult();

      if (userCredential.user != null) {
        DebugService().logInfo('リダイレクト認証成功: uid=${userCredential.user?.uid}');
        await _saveUserProfile(userCredential.user!);
      }
    } catch (e) {
      DebugService().logError('リダイレクト結果確認エラー: $e');
    }
  }

  /// Googleアカウントでログインを実行。
  /// 成功時は 'success'、キャンセル時は null、失敗時はエラーコードを返す。
  /// モバイルWebではリダイレクト方式を使用するため 'redirect' を返す。
  Future<String?> signInWithGoogle() async {
    try {
      UserCredential userCredential;

      if (kIsWeb) {
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();

        // モバイルブラウザ（iOS Safari PWA含む）ではリダイレクト方式を使用
        // ポップアップはiOS Safari PWAでブロックされるため
        if (isMobileWeb()) {
          await _auth.signInWithRedirect(googleProvider);
          // リダイレクト後はページがリロードされるため、ここには戻らない
          return 'redirect';
        } else {
          // デスクトップブラウザではポップアップ方式を使用
          userCredential = await _auth.signInWithPopup(googleProvider);
        }
      } else {
        // ネイティブプラットフォーム（Android/iOS）
        // GoogleSignInの初期化（v7で必須）
        await _ensureGoogleSignInInitialized();

        // 既存のサインインをクリア
        await _googleSignIn.signOut();

        // Google Sign-Inを開始（v7: authenticate() — 失敗時はGoogleSignInExceptionをスロー）
        final GoogleSignInAccount googleUser =
            await _googleSignIn.authenticate();

        // 認証情報を取得（v7: authenticationはsyncプロパティ）
        final googleAuth = googleUser.authentication;

        if (googleAuth.idToken == null) {
          DebugService().logError('ID Tokenがnullです。OAuth同意画面の設定を確認してください。');
          throw Exception('認証に失敗しました。ID Tokenが取得できませんでした。');
        }

        // Firebase認証情報を作成
        final credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );

        // Firebaseにサインイン
        userCredential = await _auth.signInWithCredential(credential);
      }

      // ユーザー情報をFirestoreに保存
      if (userCredential.user != null) {
        await _saveUserProfile(userCredential.user!);
      }

      DebugService().logInfo('Googleサインイン成功: uid=${userCredential.user?.uid}');
      return 'success';
    } catch (e, stackTrace) {
      DebugService().logError('Google Sign-Inエラー: $e', e, stackTrace);

      if (e is GoogleSignInException) {
        switch (e.code) {
          case GoogleSignInExceptionCode.canceled:
          case GoogleSignInExceptionCode.interrupted:
            DebugService().logWarning('サインインがキャンセルされました');
            return 'sign_in_canceled';
          case GoogleSignInExceptionCode.clientConfigurationError:
            DebugService().logError('開発者エラー: OAuth設定に問題があります');
            return 'developer_error';
          default:
            DebugService().logError('GoogleSignInException: ${e.code}');
            return 'sign_in_failed';
        }
      } else if (e is PlatformException) {
        switch (e.code) {
          case 'sign_in_failed':
            DebugService().logError('サインイン失敗: 設定を確認してください');
            return 'sign_in_failed';
          case 'sign_in_canceled':
            DebugService().logWarning('サインインがキャンセルされました');
            return 'sign_in_canceled';
          case 'network_error':
            DebugService().logError('ネットワークエラーが発生しました');
            return 'network_error';
          case 'DEVELOPER_ERROR':
            DebugService().logError('開発者エラー: OAuth設定に問題があります');
            return 'developer_error';
          default:
            return 'unknown_error';
        }
      } else if (e is FirebaseAuthException) {
        DebugService()
            .logWarning('Firebase認証例外: code=${e.code}, message=${e.message}');
        return e.code;
      }
      return 'unknown_error';
    }
  }

  /// ログアウト（Firebase/Google の両方）
  Future<void> signOut() async {
    try {
      final futures = <Future>[_auth.signOut()];
      // GoogleSignInが初期化済みの場合のみsignOutを呼び出す
      if (_googleSignInInitialized) {
        futures.add(_googleSignIn.signOut());
      }
      await Future.wait(futures);
      DebugService().logInfo('ログアウト完了');
    } catch (e) {
      DebugService().logError('ログアウトエラー: $e');
    }
  }

  /// 現在のユーザー情報を取得
  User? getUser() {
    return _auth.currentUser;
  }

  /// ユーザープロフィールをFirestoreに保存
  Future<void> _saveUserProfile(User user) async {
    try {
      final userDoc = {
        'displayName': user.displayName,
        'email': user.email,
        'photoURL': user.photoURL,
        'lastSignInAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(userDoc, SetOptions(merge: true));
    } catch (e) {
      DebugService().logError('ユーザープロフィール保存エラー: $e');
    }
  }
}
