# issue #160 設計: 共同編集時のバウンス抑止を「書き込み完了ベース」に変更

## 背景・利用者への影響

同一アカウントを複数端末で開いて編集していると（例: 1つのまいカゴアカウントをスマホ2台で共有）、
自分が編集した直後に、相手端末の古いスナップショットが遅延配信されて自分の編集が巻き戻る
ことがあった（「入力したのに消えた」体験）。

> 補足: 別ユーザー同士でリストを共同編集する機能は現状アプリに存在しない
> （`transmissions`/`syncData` 等のユーザー間共有はデッドコード）。issue 原文の
> 「2人で同時編集」は実質「同一アカウント・複数端末」を指す。`sharedTabGroupId`
> による「共有（同期）タブ」は自分のタブを結合して合計を表示する機能で、保存先は
> `users/{uid}/shops` のみ。

## 原因

`realtime_sync_manager.dart` のバウンス抑止が **編集時刻から固定10秒** の時間ベースだった。
危険な期間は「編集 → Firestore書き込み完了 → 自分の書き込みがスナップショットで返る（エコー）」
までで、その長さ = 書き込み遅延 + 配信遅延。書き込み自体に時間がかかると、エコーが返る前に
10秒が切れ、書き込み前の古いスナップショットが last-write-wins で勝ってしまっていた。

## 修正方針（対応案#1: 書き込み完了ベース）

保護を「時間」ではなく「書き込みの完了状態」で判定する。

- 各 repository に `inFlightUpdates`（書き込み未完了のID集合）を追加。
  - 編集開始時: `pendingUpdates[id] = now` ＋ `inFlightUpdates.add(id)`。
  - 書き込み成功時: `pendingUpdates[id] = now`（**完了時刻に押し直し**）＋ `inFlightUpdates.remove(id)`。
  - 書き込み失敗時: `inFlightUpdates.remove(id)`（恒久ロック防止。保護は時間窓で自然失効）。
- 保護判定 `PendingUpdatePolicy.isProtected` の純粋ロジック:
  - `inFlight == true` → 経過時間に関係なく保護（書き込み遅延が長くても巻き戻らない）。
    ただしハング対策に安全上限 `maxInFlight`（60秒）。
  - `inFlight == false` → 完了時刻から `deliveryWindow`（10秒）以内のみ保護。
- items/shops で重複していた「クリーンアップ＋マージ」を `mergePreferringProtectedLocal` に共通化。

対象は単発の `ItemRepository.updateItem` / `ShopRepository.updateShop`。
バッチ更新・並べ替えは `isBatchUpdating` フラグで同期エンジンがまるごとスキップするため
（`realtime_sync_manager` のガード）、in-flight 保護は不要。

## 競合解決の仕様（明文化）

last-write-wins は維持しつつ、次の時間的優先を明確化する:

1. **自分の書き込みが完了するまで**: 自分のローカル値が必ず勝つ（古いリモートで上書きしない）。
2. **書き込み完了後 `deliveryWindow`(10秒) 以内**: 自分のローカル値を優先（自分のエコー or
   それより新しいリモートを待つ猶予）。
3. **`deliveryWindow` 経過後**: リモートを採用する。
4. **安全上限 `maxInFlight`(60秒)**: 書き込みがハングしても、それ以降はリモートを採用する。

### 限界（既知）

- `updatedAt`/バージョンを持たないため、「書き込み完了後の窓(2)の間に来た、相手の正当な
  新しい編集」と「自分の書き込み前の古いスナップショット」を区別できない。窓の間は自分優先に
  なるため、相手の新しい編集が画面に出るのは最大で窓ぶん(～10秒)遅れることがある。
  これは旧実装（編集から10秒自分優先）と同等で、デグレではない。
- フィールド単位マージは行わない（ドキュメント単位の last-write-wins）。

## テスト

- `test/providers/managers/pending_update_policy_test.dart`:
  保護判定の純粋ロジック（書き込み遅延=in-flightを時間で再現）＋共通マージ関数。
- `test/providers/repositories/item_repository_test.dart` /
  `shop_repository_test.dart`:
  書き込み中は `inFlightUpdates` に入り、完了/失敗で外れる（恒久ロック防止）ライフサイクル。
