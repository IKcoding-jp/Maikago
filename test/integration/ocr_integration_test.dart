@Tags(['integration'])
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:flutter_test/flutter_test.dart';

/// Firebase / Cloud Functions 設定
const _firebaseApiKey = 'AIzaSyC-DgEFp7H0a6J9mFSE8_BUy1BNZ4ucgzU';
const _projectId = 'maikago2';
const _region = 'us-central1';

/// テストケース定義
class OcrTestCase {
  final String imagePath;
  final String description;
  final String? expectedName;
  final int? expectedPrice;

  const OcrTestCase({
    required this.imagePath,
    required this.description,
    this.expectedName,
    this.expectedPrice,
  });
}

/// Firebase Auth REST API でメール/パスワード認証してIDトークンを取得
Future<String> _signInWithEmailPassword(String email, String password) async {
  final url = Uri.parse(
    'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword'
    '?key=$_firebaseApiKey',
  );
  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: json.encode({
      'email': email,
      'password': password,
      'returnSecureToken': true,
    }),
  );
  if (response.statusCode != 200) {
    final body = json.decode(response.body);
    final message = body['error']?['message'] ?? response.body;
    throw Exception('Firebase Auth サインイン失敗: $message');
  }
  final body = json.decode(response.body) as Map<String, dynamic>;
  return body['idToken'] as String;
}

/// Firebase Auth IDトークンを取得
///
/// 優先順位:
/// 1. 環境変数 FIREBASE_ID_TOKEN（既存トークンを直接指定）
/// 2. test/integration/.firebase_token ファイル（既存トークンを直接指定）
/// 3. 環境変数 FIREBASE_TEST_EMAIL + FIREBASE_TEST_PASSWORD（自動サインイン）
/// 4. test/integration/.test_credentials ファイル（自動サインイン）
///    形式: {"email": "xxx@example.com", "password": "yourpassword"}
Future<String> _getTestAuthToken() async {
  // 1. 環境変数から既存トークンを取得
  final envToken = Platform.environment['FIREBASE_ID_TOKEN'];
  if (envToken != null && envToken.isNotEmpty) {
    return envToken;
  }

  // 2. ファイルから既存トークンを取得
  final tokenFile =
      File('${Directory.current.path}/test/integration/.firebase_token');
  if (tokenFile.existsSync()) {
    final token = tokenFile.readAsStringSync().trim();
    if (token.isNotEmpty) {
      return token;
    }
  }

  // 3. 環境変数からメール/パスワードで自動サインイン
  final envEmail = Platform.environment['FIREBASE_TEST_EMAIL'];
  final envPassword = Platform.environment['FIREBASE_TEST_PASSWORD'];
  if (envEmail != null &&
      envEmail.isNotEmpty &&
      envPassword != null &&
      envPassword.isNotEmpty) {
    print('環境変数の認証情報でサインイン中...');
    return _signInWithEmailPassword(envEmail, envPassword);
  }

  // 4. 認証情報ファイルから自動サインイン
  final credFile =
      File('${Directory.current.path}/test/integration/.test_credentials');
  if (credFile.existsSync()) {
    final creds =
        json.decode(credFile.readAsStringSync()) as Map<String, dynamic>;
    final email = creds['email'] as String?;
    final password = creds['password'] as String?;
    if (email != null && password != null) {
      print('認証情報ファイルでサインイン中 ($email)...');
      return _signInWithEmailPassword(email, password);
    }
  }

  throw Exception(
    'Firebase認証情報が見つかりません。\n'
    '以下のいずれかで設定してください（推奨: 方法2の自動サインイン）:\n\n'
    '【方法1】環境変数でメール/パスワードを指定（自動サインイン）:\n'
    '  FIREBASE_TEST_EMAIL=xxx@example.com FIREBASE_TEST_PASSWORD=pass \\\n'
    '    flutter test test/integration/ocr_integration_test.dart\n\n'
    '【方法2】認証情報ファイルを作成（自動サインイン、毎回不要）:\n'
    '  echo \'{"email":"xxx@example.com","password":"yourpassword"}\' \\\n'
    '    > test/integration/.test_credentials\n\n'
    '※テスト用Firebaseアカウントを Firebase Console で作成してください。\n'
    '  https://console.firebase.google.com/project/maikago2/authentication/users',
  );
}

/// VisionOcrService と同じ画像前処理を再現
Uint8List _processImage(File file) {
  final bytes = file.readAsBytesSync();
  final original = img.decodeImage(bytes);

  if (original == null) {
    print('  ⚠ 画像デコード失敗。生データを使用');
    return bytes;
  }

  var working = img.bakeOrientation(original);

  try {
    working = img.grayscale(working);
    working = img.adjustColor(working, contrast: 1.15);
  } catch (e) {
    print('  ⚠ 画像前処理エラー: $e');
  }

  const maxSize = 800;
  if (working.width > maxSize || working.height > maxSize) {
    final ratio = working.width / working.height;
    int newW, newH;
    if (ratio > 1) {
      newW = maxSize;
      newH = (maxSize / ratio).round();
    } else {
      newH = maxSize;
      newW = (maxSize * ratio).round();
    }
    working = img.copyResize(
      working,
      width: newW,
      height: newH,
      interpolation: img.Interpolation.linear,
    );
  }

  final processed = img.encodeJpg(working, quality: 85);
  print(
    '  画像: ${original.width}x${original.height} → ${working.width}x${working.height}'
    ' (${bytes.length} → ${processed.length} bytes)',
  );
  return processed;
}

/// Cloud Functions の analyzeImage を HTTP で直接呼び出し
Future<Map<String, dynamic>> _callAnalyzeImage(
  String idToken,
  String base64Image,
) async {
  final url = Uri.parse(
    'https://$_region-$_projectId.cloudfunctions.net/analyzeImage',
  );

  final response = await http.post(
    url,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $idToken',
    },
    body: json.encode({
      'data': {
        'imageUrl': base64Image,
        'timestamp': DateTime.now().toIso8601String(),
      },
    }),
  );

  if (response.statusCode != 200) {
    return {
      'error': true,
      'statusCode': response.statusCode,
      'body': response.body.length > 300
          ? response.body.substring(0, 300)
          : response.body,
    };
  }

  final body = json.decode(response.body) as Map<String, dynamic>;
  // onCall のレスポンスは {"result": {...}} でラップされる
  if (body.containsKey('result')) {
    return body['result'] as Map<String, dynamic>;
  }
  return body;
}

void main() {
  // テスト画像のベースパス
  final testImagesDir = '${Directory.current.path}/test_images';

  final testCases = [
    // --- s-series (実際の店舗撮影) ---
    OcrTestCase(
        imagePath: '$testImagesDir/s1_01.jpg', description: 's1_01 グリーンアスパラ'),
    OcrTestCase(
        imagePath: '$testImagesDir/s1_02.jpg', description: 's1_02 新たまねぎ小箱'),
    OcrTestCase(
        imagePath: '$testImagesDir/s1_04.jpg', description: 's1_04 ホットケーキミックス'),
    OcrTestCase(
        imagePath: '$testImagesDir/s1_06.jpg', description: 's1_06 メンズソックス'),
    OcrTestCase(
        imagePath: '$testImagesDir/s1_10.jpg', description: 's1_10 カップ麺'),
    OcrTestCase(
        imagePath: '$testImagesDir/s2_01.jpg', description: 's2_01 ザンギ'),
    OcrTestCase(
        imagePath: '$testImagesDir/s2_03.jpg', description: 's2_03 和牛ハンバーグ'),
    OcrTestCase(imagePath: '$testImagesDir/s3_02.jpg', description: 's3_02 白波'),
    OcrTestCase(
        imagePath: '$testImagesDir/s3_04.jpg', description: 's3_04 ほうれん草'),
    // --- web-series (web収集画像、税込価格を期待値として設定) ---
    OcrTestCase(
        imagePath: '$testImagesDir/web_01.jpg',
        description: 'web_01 ロアンヌバニラ',
        expectedPrice: 149),
    OcrTestCase(
        imagePath: '$testImagesDir/web_02.jpg',
        description: 'web_02 はくさい',
        expectedPrice: 324),
    OcrTestCase(
        imagePath: '$testImagesDir/web_03.jpg',
        description: 'web_03 麻婆豆腐の素',
        expectedPrice: 181),
    OcrTestCase(
        imagePath: '$testImagesDir/web_04.jpg',
        description: 'web_04 手塩屋',
        expectedPrice: 170),
    OcrTestCase(
        imagePath: '$testImagesDir/web_05.jpg',
        description: 'web_05 かき醤油のり',
        expectedPrice: 429),
    OcrTestCase(
        imagePath: '$testImagesDir/web_06.jpg',
        description: 'web_06 昆布さば',
        expectedPrice: 430),
    OcrTestCase(
        imagePath: '$testImagesDir/web_07.jpg',
        description: 'web_07 アンナマントマト&バジル',
        expectedPrice: 321),
    OcrTestCase(
        imagePath: '$testImagesDir/web_08.jpg',
        description: 'web_08 BOSSカフェオレ',
        expectedPrice: 85),
    OcrTestCase(
        imagePath: '$testImagesDir/web_09.jpg',
        description: 'web_09 やわらかパイ',
        expectedPrice: 138),
    OcrTestCase(
        imagePath: '$testImagesDir/web_10.jpg',
        description: 'web_10 しあわせスフレロール',
        expectedPrice: 311),
    OcrTestCase(
        imagePath: '$testImagesDir/web_11.jpg',
        description: 'web_11 コシヒカリ5kg',
        expectedPrice: 3580),
    OcrTestCase(
        imagePath: '$testImagesDir/web_12.jpg',
        description: 'web_12 卵の花',
        expectedPrice: 96),
    OcrTestCase(
        imagePath: '$testImagesDir/web_13.jpg',
        description: 'web_13 CookDo豚肉黒酢炒め',
        expectedPrice: 149),
    OcrTestCase(
        imagePath: '$testImagesDir/web_14.jpg',
        description: 'web_14 バブナイトアロマ',
        expectedPrice: 429),
  ];

  late String idToken;

  setUpAll(() async {
    print('=== OCR Integration Test ===\n');

    // テスト画像の存在確認
    for (final tc in testCases) {
      final file = File(tc.imagePath);
      if (!file.existsSync()) {
        fail('テスト画像が見つかりません: ${tc.imagePath}');
      }
    }

    // Firebase Admin SDK経由で認証トークン取得
    print('テスト用認証トークン生成中...');
    idToken = await _getTestAuthToken();
    print('認証成功（トークン取得）\n');
  });

  for (var i = 0; i < testCases.length; i++) {
    final tc = testCases[i];

    test('OCR #${i + 1}: ${tc.description}', () async {
      print('\n--- テスト #${i + 1}: ${tc.description} ---');

      // 1. 画像前処理（クライアント側と同じ）
      final file = File(tc.imagePath);
      final processed = _processImage(file);
      final base64Image = base64Encode(processed);

      // 2. レート制限対策: 1分5回制限のため13秒待機
      await Future.delayed(const Duration(seconds: 13));

      // 3. Cloud Functions 呼び出し
      print('  Cloud Functions呼び出し中...');
      final result = await _callAnalyzeImage(idToken, base64Image);
      print('  レスポンス: $result');

      // 3. 結果検証
      if (result.containsKey('error') && result['error'] == true) {
        print('  ❌ API呼び出し失敗: ${result['statusCode']}');
        print('     ${result['body']}');
        fail('Cloud Functions呼び出し失敗');
      }

      if (result['success'] == true) {
        final name = result['name'] as String?;
        final price = result['price'];
        print('  ✅ 商品名: $name');
        print('  ✅ 価格: $price円');

        // 期待値チェック（設定されている場合のみ）
        if (tc.expectedPrice != null && price != null) {
          expect(price, equals(tc.expectedPrice), reason: '価格が期待値と異なります');
        }
        if (tc.expectedName != null && name != null) {
          expect(name.contains(tc.expectedName!), isTrue,
              reason: '商品名に「${tc.expectedName}」が含まれていません: $name');
        }
      } else {
        final error = result['error'] ?? '不明なエラー';
        print('  ⚠ OCR失敗: $error');
        // 難しいケース（棚全体写真、英語ラベル）は失敗OK
        if (tc.expectedPrice != null) {
          fail('期待値が設定されているのにOCR失敗: $error');
        }
      }
    }, timeout: const Timeout(Duration(seconds: 60)));
  }
}
