// Firebase Functions v2 API
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { defineSecret } = require('firebase-functions/params');
const logger = require('firebase-functions/logger');
// v1 API（1st Gen関数用）
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const vision = require('@google-cloud/vision');
const openai = require('openai');

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
          setTimeout(() => reject(new Error('Vision APIタイムアウト')), 10000)
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

// Cloud Function to set family plan for invitee and owner when owner creates family
exports.applyFamilyPlanToGroup = onDocumentCreated(
  'families/{familyId}',
  async (event) => {
    const familyData = event.data?.data();
    if (!familyData) return null;

    const members = familyData.members || [];
    // Issue #162: Firestoreルールの人数無制限メンバー判定（isFamilyMember）のため、
    // UID文字列の配列 memberIds をファミリードキュメントに付与する。
    // これにより11人目以降のメンバーも共有データを読めるようになる。
    const memberIds = members.map((m) => m.id).filter(Boolean);
    const batch = admin.firestore().batch();

    try {
      // ファミリードキュメント自身に memberIds を書き戻す（既存メンバー配列はそのまま温存）
      if (event.data?.ref) {
        batch.set(event.data.ref, { memberIds }, { merge: true });
      }

      for (const m of members) {
        const uid = m.id;
        if (!uid) continue;
        const subRef = admin.firestore().collection('users').doc(uid).collection('subscription').doc('current');
        batch.set(subRef, {
          planType: 'family',
          isActive: true,
          expiryDate: null,
          familyMembers: memberIds,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
      }

      await batch.commit();
      logger.info('applyFamilyPlanToGroup: Updated subscriptions for members');
      return null;
    } catch (e) {
      logger.error('applyFamilyPlanToGroup error:', e);
      return null;
    }
  }
);

// Cloud Function to handle family dissolution
exports.dissolveFamily = onCall(
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', '認証が必要です');
    }

    const { familyId } = request.data;
    if (!familyId) {
      throw new HttpsError('invalid-argument', 'ファミリーIDが必要です');
    }

    try {
      const db = admin.firestore();

      const familyDoc = await db.collection('families').doc(familyId).get();
      if (!familyDoc.exists) {
        throw new HttpsError('not-found', 'ファミリーが見つかりません');
      }

      const familyData = familyDoc.data();

      if (familyData.ownerId !== request.auth.uid) {
        throw new HttpsError('permission-denied', 'ファミリーオーナーのみ解散できます');
      }

      const batch = db.batch();

      batch.update(db.collection('families').doc(familyId), {
        'dissolvedAt': admin.firestore.FieldValue.serverTimestamp(),
        'isActive': false
      });

      const members = familyData.members || [];
      for (const member of members) {
        if (member.id) {
          const userRef = db.collection('users').doc(member.id);
          batch.update(userRef, {
            'familyId': null
          });
        }
      }

      await batch.commit();
      logger.info(`Family ${familyId} dissolved successfully by ${request.auth.uid}`);

      return { success: true };
    } catch (error) {
      logger.error('dissolveFamily error:', error);
      if (error instanceof HttpsError) {
        throw error;
      }
      throw new HttpsError('internal', 'ファミリー解散に失敗しました');
    }
  }
);

// ファミリープランの期限切れ時にメンバーを元のプランに戻すCloud Function
exports.handleFamilyPlanExpiration = onDocumentUpdated(
  'users/{userId}/subscription/current',
  async (event) => {
    const beforeData = event.data?.before?.data();
    const afterData = event.data?.after?.data();
    const userId = event.params.userId;

    if (beforeData && afterData) {
      const beforePlanType = beforeData.planType;
      const afterIsActive = afterData.isActive;
      const beforeIsActive = beforeData.isActive;
      const beforeFamilyMembers = beforeData.familyMembers || [];

      if (beforePlanType === 'family' && beforeIsActive && !afterIsActive) {
        logger.info(`ファミリープラン期限切れ検知: userId=${userId}`);

        try {
          const db = admin.firestore();
          const batch = db.batch();
          const notificationTargets = [];

          for (const memberId of beforeFamilyMembers) {
            if (memberId === userId) continue;

            logger.info(`メンバーを元のプランに戻す処理開始: memberId=${memberId}`);

            const memberSubRef = db.collection('users').doc(memberId).collection('subscription').doc('current');
            const memberSubDoc = await memberSubRef.get();

            if (memberSubDoc.exists) {
              const memberData = memberSubDoc.data();
              const originalPlanType = memberData.originalPlanType || 'free';
              const originalPlan = memberData.originalPlan || null;

              logger.info(`メンバー情報: memberId=${memberId}, originalPlanType=${originalPlanType}`);

              const restoreData = {
                planType: originalPlanType,
                isActive: originalPlanType !== 'free',
                familyOwnerId: null,
                familyOwnerActive: false,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              };

              if (originalPlanType !== 'free') {
                const expiryDate = new Date();
                expiryDate.setDate(expiryDate.getDate() + 30);
                restoreData.expiryDate = admin.firestore.Timestamp.fromDate(expiryDate);
                logger.info(`有料プラン復元: 期限を30日後に設定: ${expiryDate.toISOString()}`);
              } else {
                restoreData.expiryDate = null;
                logger.info(`フリープラン復元: memberId=${memberId}`);
              }

              if (originalPlan) {
                restoreData.originalPlan = originalPlan;
              }

              restoreData.familyMembers = [];

              batch.set(memberSubRef, restoreData, { merge: true });
              notificationTargets.push(memberId);

              logger.info(`メンバー復元準備完了: memberId=${memberId}, planType=${originalPlanType}`);
            } else {
              logger.warn(`メンバーのサブスクリプション情報が見つかりません: memberId=${memberId}`);
            }
          }

          const ownerSubRef = db.collection('users').doc(userId).collection('subscription').doc('current');
          batch.set(ownerSubRef, {
            planType: 'free',
            isActive: false,
            expiryDate: null,
            familyMembers: [],
            familyOwnerId: null,
            familyOwnerActive: false,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }, { merge: true });

          const notificationResults = await Promise.allSettled(
            notificationTargets.map(memberId => sendFamilyExpirationNotification(memberId, userId))
          );
          for (const result of notificationResults) {
            if (result.status === 'rejected') {
              logger.error('通知送信失敗:', result.reason);
            }
          }

          await batch.commit();
          logger.info(`ファミリープラン期限切れ処理完了: userId=${userId}, メンバー数=${beforeFamilyMembers.length}`);

        } catch (error) {
          logger.error(`ファミリープラン期限切れ処理エラー: userId=${userId}`, error);
        }
      }
    }

    return null;
  }
);

// ファミリープラン期限切れ通知を送信する関数
async function sendFamilyExpirationNotification(memberId, ownerId) {
  try {
    const db = admin.firestore();

    const notificationRef = db.collection('users').doc(memberId).collection('notifications').doc();
    await notificationRef.set({
      type: 'family_plan_expired',
      title: 'ファミリープランの期限が切れました',
      message: '参加していたファミリープランの期限が切れたため、元のプランに戻りました。',
      ownerId: ownerId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      isRead: false,
    });

    logger.info(`ファミリープラン期限切れ通知送信: memberId=${memberId}`);
  } catch (error) {
    logger.error(`通知送信エラー: memberId=${memberId}`, error);
  }
}

// 定期的にファミリープランの期限をチェックするCloud Function（毎日実行）
exports.checkFamilyPlanExpirations = onSchedule(
  { schedule: '0 2 * * *', timeZone: 'Asia/Tokyo' },
  async () => {
    try {
      logger.info('ファミリープラン期限チェック開始');

      const db = admin.firestore();
      const now = new Date();

      const expiredFamilyPlans = await db
        .collectionGroup('subscription')
        .where('planType', '==', 'family')
        .where('isActive', '==', true)
        .where('expiryDate', '<', admin.firestore.Timestamp.fromDate(now))
        .get();

      logger.info(`期限切れファミリープラン数: ${expiredFamilyPlans.docs.length}`);

      for (const doc of expiredFamilyPlans.docs) {
        const data = doc.data();
        const userId = doc.ref.parent.parent.id;
        const familyMembers = data.familyMembers || [];

        logger.info(`期限切れファミリープラン処理: userId=${userId}, メンバー数=${familyMembers.length}`);

        await doc.ref.update({
          isActive: false,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        await handleFamilyPlanExpirationForMembers(userId, familyMembers);
      }

      logger.info('ファミリープラン期限チェック完了');
      return null;
    } catch (error) {
      logger.error('ファミリープラン期限チェックエラー:', error);
      return null;
    }
  }
);

// メンバーを元のプランに戻す処理（定期チェック用）
async function handleFamilyPlanExpirationForMembers(ownerId, familyMembers) {
  try {
    const db = admin.firestore();
    const batch = db.batch();
    const notificationTargets = [];

    for (const memberId of familyMembers) {
      if (memberId === ownerId) continue;

      logger.info(`メンバー復元処理: memberId=${memberId}`);

      const memberSubRef = db.collection('users').doc(memberId).collection('subscription').doc('current');
      const memberSubDoc = await memberSubRef.get();

      if (memberSubDoc.exists) {
        const memberData = memberSubDoc.data();
        const originalPlanType = memberData.originalPlanType || 'free';

        const restoreData = {
          planType: originalPlanType,
          isActive: originalPlanType !== 'free',
          familyOwnerId: null,
          familyOwnerActive: false,
          familyMembers: [],
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        if (originalPlanType !== 'free') {
          const expiryDate = new Date();
          expiryDate.setDate(expiryDate.getDate() + 30);
          restoreData.expiryDate = admin.firestore.Timestamp.fromDate(expiryDate);
        } else {
          restoreData.expiryDate = null;
        }

        batch.set(memberSubRef, restoreData, { merge: true });
        notificationTargets.push(memberId);
      }
    }

    const ownerSubRef = db.collection('users').doc(ownerId).collection('subscription').doc('current');
    batch.set(ownerSubRef, {
      planType: 'free',
      isActive: false,
      expiryDate: null,
      familyMembers: [],
      familyOwnerId: null,
      familyOwnerActive: false,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    const notificationResults = await Promise.allSettled(
      notificationTargets.map(memberId => sendFamilyExpirationNotification(memberId, ownerId))
    );
    for (const result of notificationResults) {
      if (result.status === 'rejected') {
        logger.error('通知送信失敗:', result.reason);
      }
    }

    await batch.commit();
    logger.info(`メンバー復元処理完了: ownerId=${ownerId}`);

  } catch (error) {
    logger.error(`メンバー復元処理エラー: ownerId=${ownerId}`, error);
  }
}

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
