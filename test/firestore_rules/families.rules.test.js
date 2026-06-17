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
import { doc, getDoc, setDoc, updateDoc } from 'firebase/firestore';

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

// 認証済みコンテキストで families ドキュメントを新規作成（create ルール検証用）
function createAs(uid, familyId, data) {
  const db = testEnv.authenticatedContext(uid).firestore();
  return setDoc(doc(db, 'families', familyId), data);
}

// 認証済みコンテキストで既存 families ドキュメントを部分更新（update ルール検証用）
function updateAs(uid, familyId, patch) {
  const db = testEnv.authenticatedContext(uid).firestore();
  return updateDoc(doc(db, 'families', familyId), patch);
}

// members 配列から memberIds（UID配列）を作る
function idsOf(members) {
  return members.map((m) => m.id);
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

// ── Issue #198 F-2: create のメンバー検証 ──────────────────────────
// create 時に「自分以外のメンバーを含められない」ことを強制する。
// 作成契約: members = [{id: ownerId}], memberIds = [ownerId]
describe('families の作成権限 (F-2)', () => {
  it('オーナー自分1人のみの作成は許可', async () => {
    await assertSucceeds(
      createAs('owner', 'f-create-ok', {
        ownerId: 'owner',
        members: [{ id: 'owner', name: 'me' }],
        memberIds: ['owner'],
      })
    );
  });

  it('他人を members に含む作成は拒否（CFが他人のsubscriptionを上書きする経路を封鎖）', async () => {
    await assertFails(
      createAs('owner', 'f-create-victim-members', {
        ownerId: 'owner',
        members: [
          { id: 'owner', name: 'me' },
          { id: 'victim', name: 'v' },
        ],
        memberIds: ['owner', 'victim'],
      })
    );
  });

  it('他人を memberIds に含む作成は拒否（members は自分だけでも）', async () => {
    await assertFails(
      createAs('owner', 'f-create-victim-ids', {
        ownerId: 'owner',
        members: [{ id: 'owner', name: 'me' }],
        memberIds: ['owner', 'victim'],
      })
    );
  });

  it('memberIds 欠如の作成は拒否（契約: [ownerId] 必須）', async () => {
    await assertFails(
      createAs('owner', 'f-create-no-ids', {
        ownerId: 'owner',
        members: [{ id: 'owner', name: 'me' }],
      })
    );
  });

  it('ownerId が自分でない作成は拒否（既存挙動の固定）', async () => {
    await assertFails(
      createAs('attacker', 'f-create-spoof', {
        ownerId: 'someoneelse',
        members: [{ id: 'someoneelse', name: 'x' }],
        memberIds: ['someoneelse'],
      })
    );
  });
});

// ── Issue #198 F-5: add-self を memberIds 化（10人上限の撤廃）──────────
describe('families の参加・脱退 (F-5: memberIds化で人数無制限)', () => {
  it('11人を超える family に12人目が add-self で参加できる', async () => {
    const members = makeMembers(11); // u0..u10（11人）
    await seedFamily('f-join', { ownerId: 'u0', members, memberIds: idsOf(members) });
    const joiner = 'u11'; // 12人目。旧 isMemberInArray(0..9) では参加判定できなかった。
    const newMembers = [...members, { id: joiner, name: 'newbie' }];
    await assertSucceeds(
      updateAs(joiner, 'f-join', { members: newMembers, memberIds: idsOf(newMembers) })
    );
  });

  it('add-self で他人も同時に追加しようとすると拒否', async () => {
    const members = makeMembers(3);
    await seedFamily('f-join-bad', { ownerId: 'u0', members, memberIds: idsOf(members) });
    const joiner = 'u9';
    const newMembers = [...members, { id: joiner, name: 'j' }, { id: 'stranger', name: 's' }];
    await assertFails(
      updateAs(joiner, 'f-join-bad', { members: newMembers, memberIds: idsOf(newMembers) })
    );
  });

  it('index>9 のメンバーが脱退できる（branch1=memberIds判定で上限なしを固定）', async () => {
    const members = makeMembers(12); // u0..u11
    await seedFamily('f-leave', { ownerId: 'u0', members, memberIds: idsOf(members) });
    const leaver = 'u11'; // 12人目
    const remaining = members.filter((m) => m.id !== leaver);
    await assertSucceeds(
      updateAs(leaver, 'f-leave', { members: remaining, memberIds: idsOf(remaining) })
    );
  });
});

// ── Issue #198 F-1: members 変更時の memberIds 整合強制 ──────────────
describe('families の memberIds 整合強制 (F-1)', () => {
  it('members だけ縮めて memberIds を据え置く update は拒否（stale 防止）', async () => {
    const members = makeMembers(5); // u0..u4
    await seedFamily('f-stale', { ownerId: 'u0', members, memberIds: idsOf(members) });
    // オーナー u0 が u4 を members から外すが memberIds は触らない → サイズ不一致
    const newMembers = members.filter((m) => m.id !== 'u4');
    await assertFails(updateAs('u0', 'f-stale', { members: newMembers }));
  });

  it('members と memberIds を揃えて縮めれば許可（正しい削除）', async () => {
    const members = makeMembers(5);
    await seedFamily('f-shrink', { ownerId: 'u0', members, memberIds: idsOf(members) });
    const newMembers = members.filter((m) => m.id !== 'u4');
    await assertSucceeds(
      updateAs('u0', 'f-shrink', { members: newMembers, memberIds: idsOf(newMembers) })
    );
  });

  it('削除フロー: オーナー削除後、対象は read も update もできない', async () => {
    const members = makeMembers(5);
    await seedFamily('f-flow', { ownerId: 'u0', members, memberIds: idsOf(members) });
    // オーナーが u4 を正しく削除（members/memberIds 両方）
    const remaining = members.filter((m) => m.id !== 'u4');
    await assertSucceeds(
      updateAs('u0', 'f-flow', { members: remaining, memberIds: idsOf(remaining) })
    );
    // u4 はもう read できない
    await assertFails(readAs('u4', 'f-flow'));
    // u4 はもう update できない
    await assertFails(updateAs('u4', 'f-flow', { someField: 'x' }));
  });
});
