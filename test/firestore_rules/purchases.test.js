// Firestore セキュリティルール: 購入データ（Issue #163）の emulator テスト
//
// premium_entitlement（サーバー検証済みのプレミアムフラグ）は Cloud Functions
// (admin SDK) 専用書き込みで、クライアントからは書き込めないことを検証する。
// 体験期間データ（one_time_purchases）は従来通りクライアント書き込み可能。

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc } from 'firebase/firestore';
import { before, after, beforeEach, describe, it } from 'mocha';

const __dirname = dirname(fileURLToPath(import.meta.url));
const rulesPath = join(__dirname, '..', '..', 'firestore.rules');

let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-maikago',
    firestore: {
      rules: readFileSync(rulesPath, 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

after(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

describe('purchases ルール（Issue #163: サーバー検証済みフラグの保護）', () => {
  const uid = 'user1';
  const entitlementPath = `users/${uid}/purchases/premium_entitlement`;
  const trialPath = `users/${uid}/purchases/one_time_purchases`;

  it('本人でも premium_entitlement は書き込めない（サーバー専用）', async () => {
    const db = testEnv.authenticatedContext(uid).firestore();
    await assertFails(
      setDoc(doc(db, entitlementPath), { isPremium: true }),
    );
  });

  it('本人は premium_entitlement を読み取れる', async () => {
    // サーバー（ルール無効）でエンタイトルメントを先に書いておく
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), entitlementPath), { isPremium: true });
    });

    const db = testEnv.authenticatedContext(uid).firestore();
    await assertSucceeds(getDoc(doc(db, entitlementPath)));
  });

  it('他人の premium_entitlement は読み取れない', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), entitlementPath), { isPremium: true });
    });

    const db = testEnv.authenticatedContext('attacker').firestore();
    await assertFails(getDoc(doc(db, entitlementPath)));
  });

  it('本人は one_time_purchases（体験期間データ）を書き込める', async () => {
    const db = testEnv.authenticatedContext(uid).firestore();
    await assertSucceeds(
      setDoc(doc(db, trialPath), { trial_history: {} }),
    );
  });

  it('未認証ユーザーは premium_entitlement を読み書きできない', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, entitlementPath)));
    await assertFails(setDoc(doc(db, entitlementPath), { isPremium: true }));
  });
});
