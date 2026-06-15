import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:maikago/services/debug_service.dart';

/// ローカルストレージから読み込んだ購入データ
class LocalPurchaseData {
  const LocalPurchaseData({
    required this.userPremiumStatus,
    required this.isTrialActive,
    required this.isTrialEverStarted,
    this.trialStartDate,
    this.trialEndDate,
  });

  final Map<String, bool> userPremiumStatus;
  final bool isTrialActive;
  final bool isTrialEverStarted;
  final DateTime? trialStartDate;
  final DateTime? trialEndDate;
}

/// Firestoreから読み込んだ購入データ
class FirestorePurchaseData {
  const FirestorePurchaseData({
    required this.isPremium,
    required this.isTrialEverStarted,
  });

  final bool isPremium;
  final bool isTrialEverStarted;
}

/// 課金データの永続化操作を担当するクラス
///
/// ローカルストレージ（SharedPreferences）とFirestoreへの
/// 読み書きを一元管理する。
class PurchasePersistence {
  // SharedPreferencesのキー定数
  static const String _prefsPremiumStatusMapKey = 'premium_status_map';
  static const String _prefsLegacyPremiumKey = 'premium_unlocked';
  static const String _legacyUserKey = '_legacy_default';

  // Firebase 依存は遅延取得にして、Firebase.initializeApp() 失敗時の
  // クラッシュを防止（オフライン/ローカルモードで継続可能にする）
  FirebaseFirestore? get _firestore {
    try {
      if (kIsWeb) {
        if (Firebase.apps.isEmpty) {
          return null;
        }
      }
      return FirebaseFirestore.instance;
    } catch (e) {
      DebugService().logError('Firebase Firestore取得エラー: $e');
      return null;
    }
  }

  FirebaseAuth? get auth {
    try {
      if (kIsWeb) {
        if (Firebase.apps.isEmpty) {
          return null;
        }
      }
      return FirebaseAuth.instance;
    } catch (e) {
      DebugService().logError('Firebase Auth取得エラー: $e');
      return null;
    }
  }

  /// ローカルストレージから購入データを読み込む
  Future<LocalPurchaseData> loadFromLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, bool> userPremiumStatus = {};

      final premiumMapString = prefs.getString(_prefsPremiumStatusMapKey);
      if (premiumMapString != null) {
        final decoded = Map<String, dynamic>.from(
            jsonDecode(premiumMapString) as Map<String, dynamic>);
        userPremiumStatus.addAll(decoded.map(
          (key, value) => MapEntry(key, value == true),
        ));
      } else {
        final legacyValue = prefs.getBool(_prefsLegacyPremiumKey);
        if (legacyValue != null) {
          userPremiumStatus[_legacyUserKey] = legacyValue;
        }
      }

      // 体験期間の情報を読み込み
      final isTrialActive = prefs.getBool('trial_active') ?? false;
      final trialStartTimestamp = prefs.getInt('trial_start_timestamp');
      final trialEndTimestamp = prefs.getInt('trial_end_timestamp');
      final isTrialEverStarted = prefs.getBool('trial_ever_started') ?? false;

      DateTime? trialStartDate;
      DateTime? trialEndDate;
      if (trialStartTimestamp != null) {
        trialStartDate =
            DateTime.fromMillisecondsSinceEpoch(trialStartTimestamp);
      }
      if (trialEndTimestamp != null) {
        trialEndDate = DateTime.fromMillisecondsSinceEpoch(trialEndTimestamp);
      }

      return LocalPurchaseData(
        userPremiumStatus: userPremiumStatus,
        isTrialActive: isTrialActive,
        isTrialEverStarted: isTrialEverStarted,
        trialStartDate: trialStartDate,
        trialEndDate: trialEndDate,
      );
    } catch (e) {
      DebugService().logError('非消耗型ローカルストレージ読み込みエラー: $e');
      return const LocalPurchaseData(
        userPremiumStatus: {},
        isTrialActive: false,
        isTrialEverStarted: false,
      );
    }
  }

  /// ローカルストレージに購入データを保存
  Future<void> saveToLocalStorage({
    required Map<String, bool> userPremiumStatus,
    required bool isTrialActive,
    required bool isTrialEverStarted,
    DateTime? trialStartDate,
    DateTime? trialEndDate,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(userPremiumStatus);
      await prefs.setString(_prefsPremiumStatusMapKey, encoded);

      // 体験期間の情報を保存
      await prefs.setBool('trial_active', isTrialActive);
      if (trialStartDate != null) {
        await prefs.setInt(
            'trial_start_timestamp', trialStartDate.millisecondsSinceEpoch);
      }
      if (trialEndDate != null) {
        await prefs.setInt(
            'trial_end_timestamp', trialEndDate.millisecondsSinceEpoch);
      }
      await prefs.setBool('trial_ever_started', isTrialEverStarted);
    } catch (e) {
      DebugService().logError('非消耗型ローカルストレージ保存エラー: $e');
    }
  }

  /// Firestoreから購入データを読み込む
  ///
  /// 戻り値がnullの場合、データが存在しないか読み込みに失敗したことを示す。
  Future<FirestorePurchaseData?> loadFromFirestore({
    required String userId,
    required String deviceFingerprint,
  }) async {
    try {
      if (userId.isEmpty) return null;

      // WebプラットフォームではFirebaseが初期化されていない可能性がある
      if (kIsWeb) {
        try {
          if (Firebase.apps.isEmpty) return null;
        } catch (e) {
          return null;
        }
      }

      final firestore = _firestore;
      if (firestore == null) return null;

      final doc = await firestore
          .collection('users')
          .doc(userId)
          .collection('purchases')
          .doc('one_time_purchases')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final map = Map<String, dynamic>.from(
          data['premium_status_map'] as Map? ?? {},
        );
        final bool status = map[userId] == true;

        // 体験期間履歴をチェック
        bool isTrialEverStarted = false;
        final trialHistory =
            data['trial_history'] as Map<String, dynamic>? ?? {};
        if (trialHistory.containsKey(deviceFingerprint)) {
          final deviceTrialData =
              trialHistory[deviceFingerprint] as Map<String, dynamic>?;
          if (deviceTrialData != null &&
              deviceTrialData['ever_started'] == true) {
            isTrialEverStarted = true;
          }
        }

        return FirestorePurchaseData(
          isPremium: status,
          isTrialEverStarted: isTrialEverStarted,
        );
      }
      return null;
    } catch (e) {
      DebugService().logError('非消耗型Firestore読み込みエラー: $e');
      return null;
    }
  }

  /// Firestoreに購入データを保存
  Future<void> saveToFirestore({
    required String userId,
    required String deviceFingerprint,
    required bool isPremium,
    required bool isTrialEverStarted,
    DateTime? trialStartDate,
    DateTime? trialEndDate,
  }) async {
    try {
      if (userId.isEmpty) return;

      // WebプラットフォームではFirebaseが初期化されていない可能性がある
      if (kIsWeb) {
        try {
          if (Firebase.apps.isEmpty) return;
        } catch (e) {
          return;
        }
      }

      final firestore = _firestore;
      if (firestore == null) return;

      // 体験期間履歴データを準備
      final Map<String, dynamic> trialHistory = {};
      if (isTrialEverStarted) {
        trialHistory[deviceFingerprint] = {
          'ever_started': isTrialEverStarted,
          'start_date': trialStartDate != null
              ? Timestamp.fromDate(trialStartDate)
              : null,
          'end_date':
              trialEndDate != null ? Timestamp.fromDate(trialEndDate) : null,
          'user_id': userId,
          'device_fingerprint': deviceFingerprint,
        };
      }

      await firestore
          .collection('users')
          .doc(userId)
          .collection('purchases')
          .doc('one_time_purchases')
          .set({
        'premium_status_map': {
          userId: isPremium,
        },
        'trial_history': trialHistory,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      DebugService().logError('非消耗型Firestore保存エラー: $e');
    }
  }
}
