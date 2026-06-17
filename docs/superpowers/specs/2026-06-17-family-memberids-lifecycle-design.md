# ファミリー共有 書き込み側 memberIds ライフサイクル堅牢化 設計

- Issue: #198（由来 PR #197 / 関連 #162）
- 日付: 2026-06-17
- 状態: 設計合意済み

## 背景

#162（PR #197）で `families` の読み取りメンバー判定を `memberIds`（UID文字列の配列）に集約し、11人目以降が共有データを読めるようにした。その際のコードレビューで、ファミリー書き込み側のセキュリティ／整合性に関する潜在指摘が3点（F-1/F-5/F-2）見つかった。

いずれも現状クライアントに `families` 書き込みコードが無い（機能休眠中）ため踏めない潜在バグだが、将来クライアントを復活させる際に必ず必要。本Issueは **rules + Cloud Functions + emulator テスト**でこの堅牢化を先に入れる（クライアント書き込みコードは本Issueでは実装しない）。

## 方針の核

> **memberIds をアクセス権の唯一のゲートにし、members と必ずサイズ整合させる。整合はルールで即時強制し、CFトリガで内容を権威的に再計算する（2層防御）。**

`memberIds` は `members`（`{id, name}` の配列）から派生する非正規化フィールド。コピーである以上「元が変わったらコピーも必ず追従」させる責任がある。現状は作成時に1回書くだけで更新経路が無いことが F-1 の根本原因。

## データ契約（families/{familyId}）

| フィールド | 型 | 役割 |
|---|---|---|
| `ownerId` | string (UID) | オーナー。作成者本人のみ |
| `members` | array of `{id, name}` | メンバー一覧（記述メタdata） |
| `memberIds` | array of UID string | アクセス権の正本（読み書きゲート）。`members` のidと一致 |

- **作成時の契約**: `members = [{id: ownerId, ...}]`（自分1人のみ）, `memberIds = [ownerId]`
- **不変条件**: `members` と `memberIds` が両方配列なら `size()` 一致

## 変更対象と各対応

### F-2【create の検証】
`firestore.rules` の `families` create:
- 既存: `ownerId == auth.uid` のみ
- 追加: **members は自分1人のみ**・**memberIds は `[ownerId]` のみ**を強制
- 効果: 他人のUIDを詰めた family を作れない → CFが他人の `subscription/current` を上書きする経路を封鎖。参加は add-self 経由のみに限定。

### F-5【add-self / self-leave を memberIds 化（10人上限撤廃）】
- **self-leave / owner-remove は branch 1（既存メンバーの全更新）＋整合不変条件で吸収**する。`isFamilyMember` は memberIds 判定＝人数無制限なので、上限なしで自然に成立。
- **add-self（非メンバーの参加）のみ専用 branch を memberIds ベースで新設**:
  - `uid` を `newMemberIds` に1件だけ追加（`newMemberIds.size() == oldMemberIds.size() + 1`）
  - 既存idは全保持（`newMemberIds.hasAll(oldMemberIds)`）
  - 追加されるのは本人のみ（`uid in newMemberIds && !(uid in oldMemberIds)`）
  - 変更キーは `members`/`memberIds`/`updatedAt` に限定
- 旧 `isMemberInArray`（members[0..9] の10人ハードコード）依存を解消。read と上限をそろえる。

### F-1【members 変更時の memberIds 整合（2層防御）】
1. **ルール（即時）**: 全 update に共通不変条件を課す。
   `members` と `memberIds` が両方配列なら `members.size() == memberIds.size()`。
   旧データ（memberIds 非配列 / members が map 形式）はこの即時チェックをスキップし、CFトリガに委ねる（回帰防止）。
   → 「membersだけ縮めて memberIds を放置」ができなくなる。
2. **CFトリガ（権威）**: `functions/` に `onDocumentUpdated('families/{familyId}')` を新設。
   - `members` から `memberIds` を再計算し、現状と異なる場合のみ書き戻す。
   - **変化なしなら早期return**（ループ防止）。
   - 内容のズレ（誤ったid除去など、サイズ整合は満たすが中身が違うケース）も数秒で是正。

## なぜ branch を増やさず減らせるか

現状の update ルールには branch 1「既存メンバーは全更新可」があり、これが既に owner-remove も self-leave も包含している（旧 branch 3/4 は branch 1 より緩いだけの実質デッドコード）。F-1 の真因は「branch 1 が members を変えても memberIds を要求しない」こと。**共通サイズ整合不変条件を1つ足すと branch 1 を含む全経路が塞がる**。残す専用 branch は「非メンバーが入る add-self」だけ＝最小権限。

更新後の update ルール構造（擬似）:
```
allow update: if auth != null &&
  memberIdsConsistent(request.resource.data) && (
    isFamilyMember(resource.data, uid) ||              // 既存メンバー/オーナー
    isJoiningSelfViaMemberIds(old, new, uid)          // 非メンバーの参加(add-self)
  );
```

## Cloud Functions の構成

- 純粋関数 `computeMemberIds(members)` を副作用のないモジュール `functions/familyMemberIds.js` に切り出す（`members` 配列 → 重複排除した UID 配列）。`index.js` の `applyFamilyPlanToGroup` からも再利用。
- `onDocumentUpdated('families/{familyId}')` トリガを `index.js` に追加し、`computeMemberIds` で再計算 → 既存 `memberIds` と内容一致なら何もしない、違えば `{ memberIds }` を merge 書き込み。
- subscription（familyMembers）の参加/脱退時の追従は本Issューの対象外（feature完成＝将来クライアント実装時）。create時の付与は既存の `applyFamilyPlanToGroup` のまま。

## テスト戦略

- **セキュリティ正本 = emulator rules テスト**（`test/firestore_rules/families.rules.test.js` に追加）:
  - F-2: 他人を含む create は拒否 / 自分1人のみの create は許可
  - F-5: 11人超の family で12人目の add-self が成功 / index>9 のメンバーの self-leave が成功（10人上限が消えたことの固定）
  - F-1: members だけ縮めて memberIds 据え置きの update は拒否（サイズ不一致）/ 両方縮めれば許可 / 削除後の対象メンバーは read・update 不可
  - 他人を memberIds に追加する add-self は拒否
- **CF純粋関数 = `node --test`**（追加依存なし。Node 20 内蔵テストランナー）:
  - `functions/test/familyMemberIds.test.js` で `computeMemberIds` の正常系・重複・壊れ要素(null/id欠如)・空配列を固定。

## 完了条件（Issue 準拠）

- [ ] メンバー削除/脱退後、対象メンバーが `memberIds` 経由で read/update できない
- [ ] 11人目以降の参加(add-self)/脱退が機能する
- [ ] create で他人を勝手にメンバーに含められない
- [ ] 上記を検証する emulator テスト＋CF純粋関数テストを追加

## スコープ外（本Issueでは触らない・フォローアップ観察）

1. **branch 1 の広い信頼モデル**: 既存メンバーは現状も全フィールド更新可（`ownerId` 書き換え・他メンバー削除も可）。F-1/F-5/F-2 の対象外。将来 add/remove 権限を整理する際に最小権限化を検討。
2. **add-self の招待未検証**: add-self ルール自体は `familyInvites` の承認を検証しない（familyId を知れば誰でも参加可）。既存の潜在ギャップで本Issue対象外。
3. **subscription の参加/脱退追従**: メンバー増減時の各メンバー `subscription/current.familyMembers` 同期は将来クライアント実装時に対応。

## 影響範囲・リスク

- 機能休眠中のため本番ユーザー影響は実質なし。既存 `families` ドキュメント（あれば）への update は、memberIds 非配列 or members が map 形式なら即時チェックをスキップするため回帰しない。
- 既存の読み取りテスト（#162 由来）は変更しない＝回帰検出に使える。
