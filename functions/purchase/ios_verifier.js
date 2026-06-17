'use strict';

/**
 * iOS（App Store）の購入レシート検証ロジック。
 *
 * App Store Server API v1 の GET /inApps/v1/transactions/{transactionId} を
 * 使い、購入トークン（transactionId）をAppleサーバーで検証する。
 *
 * 必要な外部設定（Secret Manager に登録・defineSecret() で注入）:
 * - APP_STORE_KEY_ID: App Store Connect Key ID（.p8に対応する英数字ID）
 * - APP_STORE_ISSUER_ID: App Store Connect Issuer ID（UUID形式）
 * - APP_STORE_PRIVATE_KEY: .p8ファイルの内容（"-----BEGIN PRIVATE KEY-----..."）
 *
 * Issue #204 対応: android_verifier.js と対称な構造で実装。
 */

const crypto = require('crypto');
const https = require('https');

/** アプリの Bundle ID（ios/Runner/Info.plist の CFBundleIdentifier）。 */
const BUNDLE_ID = 'com.ikcoding.maikago';

/** プレミアム有効化に対応する商品ID（Android と共通）。 */
const VALID_PRODUCT_IDS = new Set(['maikago_premium_unlock']);

/** App Store Server API のベースホスト。 */
const APP_STORE_API_HOST = 'api.storekit.itunes.apple.com';

/**
 * App Store Server API 用の署名付きJWT（Bearer トークン）を生成する。
 *
 * アルゴリズム: ES256（ECDSAキー、SHA-256ハッシュ）
 * Appleの要件: https://developer.apple.com/documentation/appstoreserverapi/generating_tokens_for_api_requests
 *
 * @param {string} keyId - App Store Connect Key ID
 * @param {string} issuerId - App Store Connect Issuer ID
 * @param {string} privateKeyPem - .p8 PEM文字列
 * @returns {string} JWT文字列
 */
function generateAppStoreJWT(keyId, issuerId, privateKeyPem) {
  const now = Math.floor(Date.now() / 1000);

  const header = base64urlEncode(
    JSON.stringify({ alg: 'ES256', kid: keyId, typ: 'JWT' })
  );
  const payload = base64urlEncode(
    JSON.stringify({
      iss: issuerId,
      iat: now,
      exp: now + 3600,
      aud: 'appstoreconnect-v1',
      bid: BUNDLE_ID,
    })
  );

  const signingInput = `${header}.${payload}`;
  const sign = crypto.createSign('SHA256');
  sign.update(signingInput);
  // ieee-p1363 形式（r||s）→ base64url に変換（ES256 標準形式）
  const signature = sign
    .sign({ key: privateKeyPem, dsaEncoding: 'ieee-p1363' })
    .toString('base64url');

  return `${signingInput}.${signature}`;
}

/**
 * App Store Server API を呼び出し、トランザクション情報を取得する。
 *
 * @param {string} transactionId - App Store が発行したトランザクションID
 * @param {string} jwt - generateAppStoreJWT で生成したJWT
 * @returns {Promise<Object>} パース済みのトランザクション情報
 */
function fetchTransaction(transactionId, jwt) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: APP_STORE_API_HOST,
      path: `/inApps/v1/transactions/${encodeURIComponent(transactionId)}`,
      method: 'GET',
      headers: {
        Authorization: `Bearer ${jwt}`,
      },
    };

    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => { body += chunk; });
      res.on('end', () => {
        if (res.statusCode === 404) {
          return reject(Object.assign(new Error('not_found'), { statusCode: 404 }));
        }
        if (res.statusCode !== 200) {
          return reject(
            Object.assign(new Error('api_error'), { statusCode: res.statusCode, body })
          );
        }
        try {
          resolve(JSON.parse(body));
        } catch {
          reject(new Error('parse_error'));
        }
      });
    });

    req.on('error', reject);
    req.end();
  });
}

/**
 * App Store Server API レスポンスの signedTransactionInfo（JWS）を
 * デコードしてペイロードを返す。
 *
 * TLSで保護されたAppleサーバーからの応答なので、JWSペイロードを
 * 信頼して base64url デコードする（署名チェーン検証は省略）。
 *
 * @param {string} signedTransactionInfo - JWS文字列
 * @returns {Object} トランザクション情報のペイロード
 */
function decodeSignedTransaction(signedTransactionInfo) {
  const parts = signedTransactionInfo.split('.');
  if (parts.length !== 3) throw new Error('invalid_jws');
  return JSON.parse(Buffer.from(parts[1], 'base64url').toString('utf8'));
}

/**
 * iOS の購入を検証する。
 *
 * @param {Object} params
 * @param {string} params.productId - 購入された商品ID
 * @param {string} params.purchaseToken - App Store が発行したトランザクションID
 * @param {Object} deps
 * @param {string} deps.keyId - App Store Connect Key ID（Secretから注入）
 * @param {string} deps.issuerId - App Store Connect Issuer ID（Secretから注入）
 * @param {string} deps.privateKey - .p8 PEM文字列（Secretから注入）
 * @returns {Promise<{valid: boolean, reason?: string, originalTransactionId?: string}>}
 */
async function verifyIosPurchase({ productId, purchaseToken }, deps) {
  if (!productId || !purchaseToken) {
    return { valid: false, reason: 'missing_params' };
  }

  if (!VALID_PRODUCT_IDS.has(productId)) {
    return { valid: false, reason: 'unknown_product' };
  }

  let jwt;
  try {
    jwt = generateAppStoreJWT(deps.keyId, deps.issuerId, deps.privateKey);
  } catch (_e) {
    return { valid: false, reason: 'jwt_error' };
  }

  let response;
  try {
    response = await fetchTransaction(purchaseToken, jwt);
  } catch (err) {
    if (err.statusCode === 404) return { valid: false, reason: 'not_found' };
    return { valid: false, reason: 'api_error' };
  }

  let txInfo;
  try {
    txInfo = decodeSignedTransaction(response.signedTransactionInfo);
  } catch {
    return { valid: false, reason: 'decode_error' };
  }

  // 商品IDが一致するか確認
  if (txInfo.productId !== productId) {
    return { valid: false, reason: 'product_mismatch' };
  }

  // 取り消し済みトランザクションは無効
  if (txInfo.revocationDate) {
    return { valid: false, reason: 'revoked' };
  }

  return {
    valid: true,
    originalTransactionId: txInfo.originalTransactionId,
  };
}

// ---- ヘルパー ----

function base64urlEncode(str) {
  return Buffer.from(str).toString('base64url');
}

module.exports = {
  verifyIosPurchase,
  generateAppStoreJWT,
  BUNDLE_ID,
  VALID_PRODUCT_IDS,
};
