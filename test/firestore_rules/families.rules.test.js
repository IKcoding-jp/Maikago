// Firestore セキュリティルールの emulator ユニットテスト
//
// 対象: firestore.rules の families/{familyId} の読み取り/更新メンバー判定
// 背景 Issue #162: メンバー判定が members[0]〜members[9] の10人ハードコードで、
//   11人目以降が共有データを読めなかった。
//   修正後は memberIds（UID文字列の配列）で人数無制限に判定できることを検証する。
//   旧データ（memberIds なし・配列形式 <=10人）の既存メンバーが回帰しないことも検証する。

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc } from 'firebase/firestore';

const __dirname = dirname(fileURLToPath(import.meta.url));
// firestore.rules はリポジトリルートにある（このファイルから2階層上）
const RULES = readFileSync(join(__dirname, '..', '..', 'firestore.rules'), 'utf8');

const PROJECT_ID = 'demo-maikago-rules';

let testEnv;

// 配列形式のメンバー（[{id, name}, ...]）を n 件生成
function makeMembers(n) {
  return Array.from({ length: n }, (_, i) => ({ id: `u${i}`, name: `member${i}` }));
}

// ルールを無効化した管理者コンテキストで families ドキュメントを作成（テストデータ投入用）
async function seedFamily(familyId, data) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'families', familyId), data);
  });
}

function readAs(uid, familyId) {
  const db = testEnv.authenticatedContext(uid).firestore();
  return getDoc(doc(db, 'families', familyId));
}

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: RULES,
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

after(async () => {
  if (testEnv) await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

describe('families の読み取り権限', () => {
  it('オーナーは読める', async () => {
    await seedFamily('f-owner', { ownerId: 'owner', members: [], memberIds: [] });
    await assertSucceeds(readAs('owner', 'f-owner'));
  });

  it('memberIds に含まれる11人目が読める（Issue #162 の本丸）', async () => {
    const members = makeMembers(11); // u0..u10
    await seedFamily('f-11', {
      ownerId: 'owner',
      members,
      memberIds: members.map((m) => m.id),
    });
    // u10 = 11人目。旧ルールでは members[10] を見ていないため拒否されていた。
    await assertSucceeds(readAs('u10', 'f-11'));
  });

  it('memberIds 形式で非メンバーは読めない', async () => {
    const members = makeMembers(3);
    await seedFamily('f-stranger', {
      ownerId: 'owner',
      members,
      memberIds: members.map((m) => m.id),
    });
    await assertFails(readAs('stranger', 'f-stranger'));
  });

  it('回帰防止: 旧配列形式（memberIds なし・10人）の10人目が読める', async () => {
    const members = makeMembers(10); // u0..u9
    await seedFamily('f-legacy-10', { ownerId: 'owner', members }); // memberIds なし
    await assertSucceeds(readAs('u9', 'f-legacy-10')); // 10人目
  });

  it('回帰防止: 旧配列形式（memberIds なし）の非メンバーは読めない', async () => {
    const members = makeMembers(5);
    await seedFamily('f-legacy-deny', { ownerId: 'owner', members });
    await assertFails(readAs('stranger', 'f-legacy-deny'));
  });

  it('Map形式（UIDキー）の members でもメンバーは読める', async () => {
    // members が「UIDをキーにした Map」形式のデータ。isFamilyMember の case 3 を検証。
    await seedFamily('f-map', {
      ownerId: 'owner',
      members: { u0: { name: 'm0' }, u1: { name: 'm1' } },
    });
    await assertSucceeds(readAs('u1', 'f-map'));
    await assertFails(readAs('stranger', 'f-map'));
  });

  it('壊れデータ: memberIds が配列でない（文字列）場合でも評価エラーで誤判定しない', async () => {
    // is list ガードにより memberIds 判定はスキップされ、members 配列フォールバックで判定される。
    const members = makeMembers(3); // u0..u2
    await seedFamily('f-broken', {
      ownerId: 'owner',
      members,
      memberIds: 'garbage', // 非配列の壊れた値
    });
    await assertSucceeds(readAs('u1', 'f-broken')); // members 配列で救済
    await assertFails(readAs('stranger', 'f-broken'));
  });

  it('境界: 旧配列形式のみ（memberIds なし・11人）では11人目は読めない（既知の制限の固定）', async () => {
    const members = makeMembers(11); // u0..u10
    await seedFamily('f-legacy-11', { ownerId: 'owner', members }); // memberIds なし
    // memberIds が無い旧データでは、配列ハードコードの制限により11人目は読めないまま。
    // → 11人目を救うには memberIds を持たせること、という修正方針を固定する。
    await assertFails(readAs('u10', 'f-legacy-11'));
  });
});
