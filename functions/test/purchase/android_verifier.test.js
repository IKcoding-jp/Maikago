'use strict';

const { test } = require('node:test');
const assert = require('node:assert');

const {
  verifyAndroidPurchase,
  PACKAGE_NAME,
} = require('../../purchase/android_verifier');

// 正規の ProductPurchase（Google Play Developer API のレスポンス相当）を返す偽API。
function fakeApi(productPurchase) {
  return {
    getProductPurchase: async () => productPurchase,
  };
}

test('正規購入（purchaseState=0）は valid:true と orderId を返す', async () => {
  const deps = fakeApi({ purchaseState: 0, orderId: 'GPA.TEST-0001' });

  const result = await verifyAndroidPurchase(
    { productId: 'maikago_premium_unlock', purchaseToken: 'valid-token' },
    deps,
  );

  assert.strictEqual(result.valid, true);
  assert.strictEqual(result.orderId, 'GPA.TEST-0001');
});

test('正規購入では正しい packageName/productId/token で API を呼ぶ', async () => {
  let calledWith = null;
  const deps = {
    getProductPurchase: async (args) => {
      calledWith = args;
      return { purchaseState: 0, orderId: 'GPA.TEST-0002' };
    },
  };

  await verifyAndroidPurchase(
    { productId: 'maikago_premium_unlock', purchaseToken: 'tok-123' },
    deps,
  );

  assert.deepStrictEqual(calledWith, {
    packageName: PACKAGE_NAME,
    productId: 'maikago_premium_unlock',
    token: 'tok-123',
  });
});

test('未知の productId は valid:false（unknown_product）', async () => {
  const deps = fakeApi({ purchaseState: 0, orderId: 'x' });

  const result = await verifyAndroidPurchase(
    { productId: 'not_a_real_product', purchaseToken: 'valid-token' },
    deps,
  );

  assert.strictEqual(result.valid, false);
  assert.strictEqual(result.reason, 'unknown_product');
});

test('purchaseToken 欠落は valid:false（missing_params）', async () => {
  const deps = fakeApi({ purchaseState: 0 });

  const result = await verifyAndroidPurchase(
    { productId: 'maikago_premium_unlock', purchaseToken: '' },
    deps,
  );

  assert.strictEqual(result.valid, false);
  assert.strictEqual(result.reason, 'missing_params');
});

test('キャンセル済み（purchaseState=1）は valid:false（not_purchased）', async () => {
  const deps = fakeApi({ purchaseState: 1, orderId: 'GPA.CANCELED' });

  const result = await verifyAndroidPurchase(
    { productId: 'maikago_premium_unlock', purchaseToken: 'valid-token' },
    deps,
  );

  assert.strictEqual(result.valid, false);
  assert.strictEqual(result.reason, 'not_purchased');
});

test('保留中（purchaseState=2）は valid:false（not_purchased）', async () => {
  const deps = fakeApi({ purchaseState: 2 });

  const result = await verifyAndroidPurchase(
    { productId: 'maikago_premium_unlock', purchaseToken: 'valid-token' },
    deps,
  );

  assert.strictEqual(result.valid, false);
  assert.strictEqual(result.reason, 'not_purchased');
});

test('API がエラーを投げたら valid:false（api_error）— 例外を握らず判定に変換', async () => {
  const deps = {
    getProductPurchase: async () => {
      throw new Error('network down');
    },
  };

  const result = await verifyAndroidPurchase(
    { productId: 'maikago_premium_unlock', purchaseToken: 'valid-token' },
    deps,
  );

  assert.strictEqual(result.valid, false);
  assert.strictEqual(result.reason, 'api_error');
});

test('購入が見つからない（null）は valid:false（not_found）', async () => {
  const deps = fakeApi(null);

  const result = await verifyAndroidPurchase(
    { productId: 'maikago_premium_unlock', purchaseToken: 'valid-token' },
    deps,
  );

  assert.strictEqual(result.valid, false);
  assert.strictEqual(result.reason, 'not_found');
});
