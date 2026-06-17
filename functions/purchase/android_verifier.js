'use strict';

/**
 * Android（Google Play）の購入レシート検証ロジック。
 *
 * Google Play Developer API の `purchases.products.get` を用いて購入トークンを
 * 検証する純粋ロジック。API クライアントは [deps.getProductPurchase] として
 * 外から注入する（テスト時はモックを渡し、本番は googleapis を使う）。
 *
 * Issue #163 対応案#1: 改竄に対する真の防御をサーバー側で行う。
 */

/** アプリの Android パッケージ名（android/app/build.gradle の applicationId と一致）。 */
const PACKAGE_NAME = 'com.ikcoding.maikago';

/** プレミアム有効化に対応する商品ID。 */
const VALID_PRODUCT_IDS = new Set(['maikago_premium_unlock']);

/**
 * Android の購入を検証する。
 *
 * @param {Object} params
 * @param {string} params.productId - 購入された商品ID
 * @param {string} params.purchaseToken - Google Play が発行した購入トークン
 * @param {Object} deps
 * @param {(args: {packageName: string, productId: string, token: string}) =>
 *   Promise<Object|null>} deps.getProductPurchase
 *   - Play Developer API の ProductPurchase を返す関数（注入）
 * @returns {Promise<{valid: boolean, reason?: string, orderId?: string}>}
 */
async function verifyAndroidPurchase({ productId, purchaseToken }, deps) {
  if (!productId || !purchaseToken) {
    return { valid: false, reason: 'missing_params' };
  }

  if (!VALID_PRODUCT_IDS.has(productId)) {
    return { valid: false, reason: 'unknown_product' };
  }

  let purchase;
  try {
    purchase = await deps.getProductPurchase({
      packageName: PACKAGE_NAME,
      productId,
      token: purchaseToken,
    });
  } catch (_e) {
    // API 失敗は「検証できなかった」として扱い、例外は握って判定に変換する。
    // （プレミアムは付与しない。呼び出し側で再試行可能にする）
    return { valid: false, reason: 'api_error' };
  }

  if (!purchase) {
    return { valid: false, reason: 'not_found' };
  }

  // purchaseState: 0=Purchased / 1=Canceled / 2=Pending
  if (purchase.purchaseState !== 0) {
    return { valid: false, reason: 'not_purchased' };
  }

  return { valid: true, orderId: purchase.orderId };
}

module.exports = { verifyAndroidPurchase, PACKAGE_NAME, VALID_PRODUCT_IDS };
