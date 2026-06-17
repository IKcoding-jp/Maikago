'use strict';

const { google } = require('googleapis');

/**
 * サービスアカウントJSON文字列から、Google Play Developer API を呼ぶ
 * `getProductPurchase` 関数を構築する。
 *
 * android_verifier.js に注入する依存（deps）として使う。検証ロジック本体は
 * android_verifier.js 側にあり、本モジュールは googleapis への薄いグルーのみ。
 *
 * @param {string} serviceAccountJson - GOOGLE_PLAY_SERVICE_ACCOUNT_JSON の値
 *   （サービスアカウント鍵のJSON文字列）
 * @returns {{getProductPurchase: (args: {packageName: string,
 *   productId: string, token: string}) => Promise<Object>}}
 */
function createAndroidPublisherDeps(serviceAccountJson) {
  const credentials = JSON.parse(serviceAccountJson);

  const auth = new google.auth.GoogleAuth({
    credentials,
    scopes: ['https://www.googleapis.com/auth/androidpublisher'],
  });

  const androidpublisher = google.androidpublisher({ version: 'v3', auth });

  return {
    getProductPurchase: async ({ packageName, productId, token }) => {
      const res = await androidpublisher.purchases.products.get({
        packageName,
        productId,
        token,
      });
      return res.data;
    },
  };
}

module.exports = { createAndroidPublisherDeps };
