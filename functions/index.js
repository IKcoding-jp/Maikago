// Firebase Functions v2 API
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');
const vision = require('@google-cloud/vision');
const openai = require('openai');
const { verifyAndroidPurchase } = require('./purchase/android_verifier');
const {
  createAndroidPublisherDeps,
} = require('./purchase/android_publisher_client');
const { verifyIosPurchase } = require('./purchase/ios_verifier');

admin.initializeApp();

// Google Cloud Vision APIクライアントを遅延初期化
let _visionClient = null;
function getVisionClient() {
  if (!_visionClient) {
    _visionClient = new vision.ImageAnnotatorClient();
  }
  return _visionClient;
}

// Secret Manager でAPIキーを管理（2nd Gen関数用）
const openaiApiKey = defineSecret('OPENAI_API_KEY');

// Google Play Developer API 用サービスアカウント鍵（JSON文字列）。
// 購入レシート検証（Issue #163）で使用。Secret Manager で管理。
const googlePlayServiceAccount = defineSecret('GOOGLE_PLAY_SERVICE_ACCOUNT_JSON');

// App Store Server API 用認証情報（Issue #204）。Secret Manager で管理。
// 取得方法: App Store Connect → ユーザーとアクセス → キー → App Store Connect API
const appStoreKeyId = defineSecret('APP_STORE_KEY_ID');
const appStoreIssuerId = defineSecret('APP_STORE_ISSUER_ID');
const appStorePrivateKey = defineSecret('APP_STORE_PRIVATE_KEY');

// Android 購入検証用クライアントを遅延初期化
let _androidPurchaseDeps = null;
function getAndroidPurchaseDeps() {
  if (!_androidPurchaseDeps) {
    // 環境変数（.env）を優先し、Secret Manager にフォールバック
    const json =
      process.env.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON ||
      googlePlayServiceAccount.value();
    _androidPurchaseDeps = createAndroidPublisherDeps(json);
  }
  return _androidPurchaseDeps;
}

// OpenAI APIクライアントを遅延初期化
let _openaiClient = null;
function getOpenAIClient() {
  if (!_openaiClient) {
    // 環境変数（.env）を優先し、Secret Managerにフォールバック
    const apiKey = process.env.OPENAI_API_KEY || openaiApiKey.value();
    _openaiClient = new openai.OpenAI({ apiKey });
  }
  return _openaiClient;
}

// 画像サイズ上限（10MB）
const MAX_IMAGE_SIZE = 10 * 1024 * 1024;

// レート制限設定
const RATE_LIMIT_PER_MINUTE = 50;
const RATE_LIMIT_PER_DAY = 500;

/**
 * レート制限チェック
 * @param {string} userId - ユーザーID
 * @returns {Promise<void>} レート制限超過時はHttpsErrorをスロー
 */
async function checkRateLimit(userId) {
  const db = admin.firestore();
  const now = Date.now();
  const oneMinuteAgo = now - 60 * 1000;
  const oneDayAgo = now - 24 * 60 * 60 * 1000;

  const rateLimitRef = db.collection('rateLimits').doc(userId);

  return db.runTransaction(async (transaction) => {
    const doc = await transaction.get(rateLimitRef);
    const data = doc.exists ? doc.data() : { calls: [] };

    // 古いエントリーを削除し、直近のものだけ保持
    const recentCalls = (data.calls || []).filter(ts => ts > oneDayAgo);
    const callsLastMinute = recentCalls.filter(ts => ts > oneMinuteAgo);

    if (callsLastMinute.length >= RATE_LIMIT_PER_MINUTE) {
      throw new HttpsError(
        'resource-exhausted',
        `1分あたりの呼び出し回数制限（${RATE_LIMIT_PER_MINUTE}回）を超えました。しばらくしてから再試行してください。`
      );
    }

    if (recentCalls.length >= RATE_LIMIT_PER_DAY) {
      throw new HttpsError(
        'resource-exhausted',
        `1日あたりの呼び出し回数制限（${RATE_LIMIT_PER_DAY}回）を超えました。明日再試行してください。`
      );
    }

    // 新しい呼び出しを記録
    recentCalls.push(now);
    transaction.set(rateLimitRef, {
      calls: recentCalls,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
}

// Cloud Function to analyze image using OCR and ChatGPT (シンプル版)
exports.analyzeImage = onCall(
  { memory: '512MiB', timeoutSeconds: 60, secrets: [openaiApiKey] },
  async (request) => {
    // 認証チェック
    if (!request.auth) {
      throw new HttpsError('unauthenticated', '認証が必要です');
    }

    // レート制限チェック
    await checkRateLimit(request.auth.uid);

    const { imageUrl, timestamp } = request.data;
    if (!imageUrl) {
      throw new HttpsError('invalid-argument', '画像データが必要です');
    }

    try {
      logger.info('画像解析開始（シンプル版）:', { userId: request.auth.uid, timestamp });

      // base64エンコードされた画像データを処理
      const imageBuffer = Buffer.from(imageUrl, 'base64');
      logger.info('画像バッファサイズ(byte):', imageBuffer.length);

      // 入力サイズ制限チェック（10MB上限）
      if (imageBuffer.length > MAX_IMAGE_SIZE) {
        throw new HttpsError(
          'invalid-argument',
          '画像サイズが上限（10MB）を超えています。画像を小さくして再試行してください。'
        );
      }

      // 1. Google Cloud Vision APIでOCR実行（シンプル版）
      logger.info('Vision APIでOCR実行中...');
      const [visionResult] = await Promise.race([
        getVisionClient().documentTextDetection({
          image: { content: imageBuffer },
          imageContext: { languageHints: ['ja', 'en'] }
        }),
        new Promise((_, reject) =>
          setTimeout(() => reject(new Error('Vision APIタイムアウト')), 12000)
        )
      ]);

      const fullTextAnnotation = visionResult.fullTextAnnotation;
      const textAnnotations = visionResult.textAnnotations;

      if (!fullTextAnnotation && (!textAnnotations || textAnnotations.length === 0)) {
        logger.warn('テキストが検出されませんでした');
        return {
          success: false,
          error: 'テキストが検出されませんでした',
          timestamp: timestamp || new Date().toISOString()
        };
      }

      // OCRテキストを取得
      const ocrText = (fullTextAnnotation && fullTextAnnotation.text) ||
                     (textAnnotations && textAnnotations[0] && textAnnotations[0].description) || '';

      if (!ocrText.trim()) {
        logger.warn('OCRテキストが空でした');
        return {
          success: false,
          error: 'OCRテキストが空でした',
          timestamp: timestamp || new Date().toISOString()
        };
      }

      logger.info('OCRテキスト取得完了:', ocrText.slice(0, 100) + '...');

      // 2. ChatGPTで商品情報を抽出
      logger.info('ChatGPTで商品情報を抽出中...');
      // OpenAIクライアントをリクエストごとに再生成（Secretの値が変わる可能性があるため）
      _openaiClient = null;
      const chatResponse = await Promise.race([
        getOpenAIClient().chat.completions.create({
          model: 'gpt-4o-mini',
          messages: [
            {
              role: 'system',
              content: `あなたは商品の値札を解析する専門家です。OCRで読み取ったテキストから商品名と税込価格を抽出してください。

出力形式（JSON）:
{
  "name": "商品名",
  "price": 税込価格（整数）
}

【価格の選択ルール（最重要 - 必ず全ルールに従うこと）】:
1. 「税込」「税込価格」「(税込)」「[税込」「税込み」などのラベルが付いた価格を最優先で選択する。本体価格がどれほど大きく目立っていても、税込ラベル付きの価格を必ず選ぶこと
2. 「本体価格」「本体」とラベルされた価格は税抜き価格なので絶対に選ばない
3. 小数を含む価格（例:「149.04円」「85.32円」「429,84円」）は税込価格である可能性が極めて高い。カンマやピリオドが小数点として使われている場合がある。小数点以下を切り捨てて整数で返す（例: 85.32→85, 321.84→321, 429,84→429）
4. OCRで小数点が欠落して「税込31104円」のように不自然に大きい数値になっている場合、元は「311.04円」である可能性が高い。末尾2桁を小数部分とみなし整数部分を返す（31104→311）
5. 価格が1種類のみで「本体」「本体価格」のラベルがない場合は、そのまま税込価格として返す（税率計算をしてはならない）
6. 「本体」ラベル付きの価格しかなく税込価格が見つからない場合のみ税率計算する:
   - 食品・飲料: 本体価格 × 1.08 の整数部分
   - それ以外: 本体価格 × 1.10 の整数部分

【その他】:
- 商品名は簡潔に（例：「やわらかパイ」「カップ麺」）
- 商品名や価格が不明確な場合はnullを返す`
            },
            {
              role: 'user',
              content: `以下のOCRテキストから商品名と税込価格を抽出してください:\n\n${ocrText}`
            }
          ],
          temperature: 0.1,
          max_tokens: 200
        }),
        new Promise((_, reject) =>
          setTimeout(() => reject(new Error('ChatGPTタイムアウト')), 15000)
        )
      ]);

      const chatContent = chatResponse.choices[0]?.message?.content;
      if (!chatContent) {
        throw new Error('ChatGPTからの応答が空でした');
      }

      logger.info('ChatGPT応答:', chatContent);

      // JSONパース
      let productInfo;
      try {
        const jsonMatch = chatContent.match(/\{[\s\S]*\}/);
        if (jsonMatch) {
          productInfo = JSON.parse(jsonMatch[0]);
        } else {
          throw new Error('JSON形式が見つかりません');
        }
      } catch (parseError) {
        logger.error('JSONパースエラー:', parseError);
        throw new Error('ChatGPTの応答を解析できませんでした');
      }

      // 結果の検証
      if (!productInfo.name || !productInfo.price) {
        logger.warn('商品情報が不完全:', productInfo);
        return {
          success: false,
          error: '商品名または価格を抽出できませんでした',
          ocrText: ocrText,
          timestamp: timestamp || new Date().toISOString()
        };
      }

      const result = {
        success: true,
        name: productInfo.name,
        price: parseInt(productInfo.price),
        ocrText: ocrText,
        timestamp: timestamp || new Date().toISOString(),
        userId: request.auth.uid
      };

      logger.info('解析完了:', { name: result.name, price: result.price });
      return result;

    } catch (error) {
      logger.error('画像解析エラー:', error);

      if (error instanceof HttpsError) {
        throw error;
      }

      if (error.message && error.message.includes('タイムアウト')) {
        throw new HttpsError('deadline-exceeded', '解析がタイムアウトしました。画像サイズを小さくして再試行してください。');
      }

      throw new HttpsError('internal', '画像解析に失敗しました。しばらくしてから再試行してください。');
    }
  }
);

// デバッグ用のテスト関数
exports.testConnection = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', '認証が必要です');
  }

  try {
    logger.info('テスト接続確認:', { userId: request.auth.uid, timestamp: new Date().toISOString() });

    return {
      success: true,
      message: 'Cloud Functions接続正常',
      timestamp: new Date().toISOString(),
      userId: request.auth.uid
    };
  } catch (error) {
    logger.error('テスト接続エラー:', error);
    throw new HttpsError('internal', 'テスト接続に失敗しました');
  }
});

// レシピテキストの最大文字数
const MAX_RECIPE_TEXT_LENGTH = 5000;

// Cloud Function to parse recipe text and extract ingredients（2nd Gen）
exports.parseRecipe = onCall(
  { secrets: [openaiApiKey] },
  async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', '認証が必要です');
  }

  const { recipeText } = request.data;
  if (!recipeText) {
    throw new HttpsError('invalid-argument', 'レシピテキストが必要です');
  }

  // テキスト長制限チェック
  if (recipeText.length > MAX_RECIPE_TEXT_LENGTH) {
    throw new HttpsError(
      'invalid-argument',
      `レシピテキストが長すぎます（${recipeText.length}文字）。${MAX_RECIPE_TEXT_LENGTH}文字以下にしてください。`
    );
  }

  try {
    logger.info('レシピ解析開始:', { userId: request.auth.uid });

    _openaiClient = null;
    const chatResponse = await Promise.race([
      getOpenAIClient().chat.completions.create({
        model: 'gpt-4o-mini',
        response_format: { type: 'json_object' },
        messages: [
          {
            role: 'system',
            content: `あなたはレシピから材料を抽出する専門家です。
レシピテキストから「料理名（レシピ名）」と「材料リスト」を抽出し、JSONで返してください。

抽出ルール:
1. title: レシピの料理名を簡潔に抽出する。不明な場合は「レシピから取り込み」とする。
2. ingredients: 材料名と分量を正確に抽出する。調味料（醤油、みりん、砂糖等）も含めて全ての材料を抽出すること。
3. 曖昧な分量（「適量」「少々」「ひとつまみ」等）は quantity を null にする。
4. 材料を正規化する（全角半角の統一、余分な空白削除、一般的な表記への統一）。

出力形式 (JSON):
{
  "title": "肉じゃが",
  "ingredients": [
    {
      "name": "玉ねぎ",
      "quantity": "1個",
      "normalizedName": "玉ねぎ",
      "confidence": 1.0,
      "notes": null
    }
  ]
}`
          },
          {
            role: 'user',
            content: `以下のレシピテキストから材料を抽出してください:\n\n${recipeText}`
          }
        ],
        temperature: 0.1,
      }),
      new Promise((_, reject) =>
        setTimeout(() => reject(new Error('ChatGPTタイムアウト')), 15000)
      )
    ]);

    const content = chatResponse.choices[0]?.message?.content;
    if (!content) {
      throw new Error('ChatGPTからの応答が空でした');
    }

    const result = JSON.parse(content);
    logger.info('レシピ解析完了:', { title: result.title, ingredientCount: result.ingredients?.length || 0 });

    return {
      success: true,
      title: result.title || 'レシピから取り込み',
      ingredients: result.ingredients || [],
    };
  } catch (error) {
    logger.error('レシピ解析エラー:', error);
    if (error instanceof HttpsError) {
      throw error;
    }
    if (error.message && error.message.includes('タイムアウト')) {
      throw new HttpsError('deadline-exceeded', 'レシピ解析がタイムアウトしました。しばらくしてから再試行してください。');
    }
    throw new HttpsError('internal', 'レシピ解析に失敗しました。しばらくしてから再試行してください。');
  }
});

// Cloud Function to summarize product name
exports.summarizeProductName = onCall(
  { secrets: [openaiApiKey] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', '認証が必要です');
    }

    const { originalName } = request.data;
    if (!originalName) {
      throw new HttpsError('invalid-argument', '商品名が必要です');
    }

    try {
      _openaiClient = null;
      const chatResponse = await Promise.race([
        getOpenAIClient().chat.completions.create({
          model: 'gpt-4o-mini',
          messages: [
            {
              role: 'system',
              content: `あなたは商品名を簡潔に要約する専門家です。
以下のルールに従って商品名を要約してください：

1. メーカー名、商品名のみを抽出
2. 不要な説明文・キーワードを削除（内容量、用途説明、キャッチフレーズ、包装説明、配送関連など）
3. 商品名の一部として必要なキーワードは保持（味の種類、形状、種類など）
4. 最大20文字以内に収める
5. 日本語で回答`
            },
            {
              role: 'user',
              content: `以下の商品名を要約してください：\n${originalName}`
            }
          ],
          max_tokens: 50,
        }),
        new Promise((_, reject) =>
          setTimeout(() => reject(new Error('ChatGPTタイムアウト')), 10000)
        )
      ]);

      const content = chatResponse.choices[0]?.message?.content?.trim();
      if (!content) {
        return { success: false, summarizedName: '' };
      }

      return { success: true, summarizedName: content };
    } catch (error) {
      logger.error('商品名要約エラー:', error);
      if (error instanceof HttpsError) {
        throw error;
      }
      throw new HttpsError('internal', '商品名要約に失敗しました。しばらくしてから再試行してください。');
    }
  }
);

// Cloud Function to check if two ingredients are the same
exports.checkIngredientSimilarity = onCall(
  { secrets: [openaiApiKey] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', '認証が必要です');
    }

    const { name1, name2 } = request.data;
    if (!name1 || !name2) {
      throw new HttpsError('invalid-argument', '2つの材料名が必要です');
    }

    // 完全一致チェック
    if (name1.trim() === name2.trim()) {
      return { success: true, isSame: true };
    }

    try {
      _openaiClient = null;
      const chatResponse = await Promise.race([
        getOpenAIClient().chat.completions.create({
          model: 'gpt-4o-mini',
          messages: [
            {
              role: 'system',
              content: 'あなたは買い物リストの整理ヘルパーです。2つの材料が同じ食材を指しているかどうかを判定してください。判定は "true" または "false" のみで返答してください。'
            },
            {
              role: 'user',
              content: `「${name1}」と「${name2}」は同じ食材ですか？`
            }
          ],
          temperature: 0,
          max_tokens: 10,
        }),
        new Promise((_, reject) =>
          setTimeout(() => reject(new Error('ChatGPTタイムアウト')), 5000)
        )
      ]);

      const content = chatResponse.choices[0]?.message?.content || '';
      const isSame = content.toLowerCase().includes('true');

      return { success: true, isSame };
    } catch (error) {
      logger.error('材料同一性判定エラー:', error);
      if (error instanceof HttpsError) {
        throw error;
      }
      throw new HttpsError('internal', '材料同一性判定に失敗しました。しばらくしてから再試行してください。');
    }
  }
);

// Cloud Function: 購入レシートをサーバー側で検証する（Issue #163 対応案#1/#3）
//
// クライアントの PurchaseDetails を信頼せず、Google Play Developer API で
// 購入トークンを検証する。検証成功時のみ、サーバー専用ドキュメント
// users/{uid}/purchases/premium_entitlement に isPremium:true を書き込む
// （admin SDK は Firestore ルールを迂回するため、クライアントは書き込めない）。
exports.verifyPurchase = onCall(
  {
    memory: '256MiB',
    timeoutSeconds: 30,
    secrets: [googlePlayServiceAccount, appStoreKeyId, appStoreIssuerId, appStorePrivateKey],
  },
  async (request) => {
    // 認証チェック
    if (!request.auth) {
      throw new HttpsError('unauthenticated', '認証が必要です');
    }

    // レート制限チェック（既存のOCR等と共有）
    await checkRateLimit(request.auth.uid);

    const { platform, productId, purchaseToken } = request.data || {};
    if (!platform || !productId || !purchaseToken) {
      throw new HttpsError(
        'invalid-argument',
        'platform / productId / purchaseToken が必要です'
      );
    }

    const uid = request.auth.uid;

    // iOS: App Store Server API で検証（Issue #204）
    if (platform === 'ios') {
      let iosResult;
      try {
        iosResult = await verifyIosPurchase(
          { productId, purchaseToken },
          {
            keyId: appStoreKeyId.value(),
            issuerId: appStoreIssuerId.value(),
            privateKey: appStorePrivateKey.value(),
          }
        );
      } catch (error) {
        logger.error('iOS購入検証で予期せぬエラー', { uid, error: error.message });
        throw new HttpsError('internal', '購入検証に失敗しました');
      }

      if (!iosResult.valid) {
        logger.warn('iOS購入検証に失敗（プレミアム付与せず）', {
          uid, productId, reason: iosResult.reason,
        });
        if (iosResult.reason === 'api_error') {
          throw new HttpsError(
            'unavailable',
            '検証サーバーに接続できませんでした。時間をおいて再試行してください'
          );
        }
        throw new HttpsError('permission-denied', '購入を検証できませんでした');
      }

      await admin
        .firestore()
        .collection('users')
        .doc(uid)
        .collection('purchases')
        .doc('premium_entitlement')
        .set(
          {
            isPremium: true,
            productId,
            platform: 'ios',
            originalTransactionId: iosResult.originalTransactionId || null,
            verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );

      logger.info('iOS購入検証成功・エンタイトルメント付与', {
        uid,
        productId,
        originalTransactionId: iosResult.originalTransactionId,
      });

      return { verified: true };
    }

    if (platform !== 'android') {
      throw new HttpsError(
        'invalid-argument',
        `未対応のプラットフォーム: ${platform}`
      );
    }

    let result;
    try {
      result = await verifyAndroidPurchase(
        { productId, purchaseToken },
        getAndroidPurchaseDeps()
      );
    } catch (error) {
      // 検証ロジックは例外を握って reason に変換するため、ここに来るのは
      // クライアント構築失敗（鍵不正）等の想定外エラーのみ。
      logger.error('購入検証で予期せぬエラー', {
        uid,
        error: error.message,
      });
      throw new HttpsError('internal', '購入検証に失敗しました');
    }

    if (!result.valid) {
      logger.warn('購入検証に失敗（プレミアム付与せず）', {
        uid,
        productId,
        reason: result.reason,
      });
      // API一時障害は再試行可能なエラーとして返す
      if (result.reason === 'api_error') {
        throw new HttpsError(
          'unavailable',
          '検証サーバーに接続できませんでした。時間をおいて再試行してください'
        );
      }
      throw new HttpsError('permission-denied', '購入を検証できませんでした');
    }

    // サーバー専用ドキュメントにエンタイトルメントを書き込む
    await admin
      .firestore()
      .collection('users')
      .doc(uid)
      .collection('purchases')
      .doc('premium_entitlement')
      .set(
        {
          isPremium: true,
          productId,
          platform: 'android',
          orderId: result.orderId || null,
          verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

    logger.info('購入検証成功・エンタイトルメント付与', {
      uid,
      productId,
      orderId: result.orderId,
    });

    return { verified: true };
  }
);
