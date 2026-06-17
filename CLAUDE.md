# CLAUDE.md

まいカゴ — 買い物リストアプリ（Flutter / iOS・Android・Web、Google Play 公開済み）。日本語で返答する。
可変値（バージョン・テーマ数等）はコードを正とし、この文書に固定しない。
UI・色・セキュリティの詳細は `.claude/rules/`（編集対象ファイルに応じ自動適用）を正とする。

## 最優先原則（すべてに優先）

1. **データを消さない。** ローカル削除はクラウド保存の成功確認後のみ。`clearGuestData()` は全件移行成功後のみ呼ぶ。
2. **金額を間違えない。** 計算式を screens/widgets に直書きしない。`SharedTabManager.getDisplayTotal()`（`(price×quantity×(1-discount)).round()`、丸めはアイテム単位で1回）が唯一の正。
3. **失敗を隠さない。** 保存・同期・削除の失敗は必ず通知。`catch`→`debugPrint` だけの握りつぶし禁止。`debugPrint` に機密（ユーザーデータ・トークン・キー）を出さない。
4. **Web で落とさない。** Web 到達コードで `dart:io`（`Platform.isXX`/`File`）を直接使わない。`kIsWeb`/`defaultTargetPlatform` で分岐。
5. **課金を欺かない。** 使用回数カウント・プレミアム判定を「ユーザーが得た価値」と一致させ、キャンセル経路で消費しない。

## 作業前に読むファイル

| 機能 | ファイル |
|---|---|
| 金額・合計・割引 | `lib/providers/managers/shared_tab_manager.dart`（`getDisplayTotal`）、`lib/models/list.dart` |
| アイテム/ショップ CRUD | `lib/providers/repositories/`（楽観的更新・ロールバック） |
| 同期・共有タブ | `lib/providers/managers/realtime_sync_manager.dart`、`shared_tab_manager.dart` |
| 認証・ゲスト移行 | `lib/providers/auth_provider.dart`、`lib/providers/data_provider.dart`（`migrateGuestDataToCloud`） |
| 課金・広告 | `lib/services/one_time_purchase_service.dart`、`lib/services/feature_access_control.dart`、`lib/services/ad/` |
| OCR・レシピ | `lib/services/hybrid_ocr_service.dart`、`functions/index.js` |
| ルーティング | `lib/router.dart`（go_router。`context.push()`/`context.go()`） |

## ドメインルール

**金額・入力値**
- 計算式は共通関数のみ。式を変えたら境界値テスト（割引0%/50%/100%×奇数価格×複数個）を同PRで追加。
- `discount` 0.0〜1.0・`price`/`quantity` 0以上を、モデル境界（fromJson/copyWith）と入力UIの両方で検証する。

**Firestore 同期・楽観的更新**
- 楽観的更新は **ロールバック＋通知をセット**で（通知なしは不完全実装）。遷移後も通知できる手段を事前確保する。
- 読むデータは壊れている前提。fromJson はドキュメント単位で防御し、壊れた1件で全体を道連れにしない。
- 複数ドキュメントの一括更新・削除は `WriteBatch`/transaction を第一候補にし、部分失敗の整合性（成功/失敗を区別しロールバック）を設計する。Stream 購読中はバッチ更新でUI抑制。

**共有タブ・共同編集**
- last-write-wins を無条件採用しない。競合解決を変えるなら PR に2ユーザー同時編集の挙動を明記。
- エコーバック保護（`pendingUpdates`）の時間窓を変えるなら書き込み遅延＋配信遅延を考慮する。

**ゲスト移行**
- 二重実行ガードを設ける。部分失敗時はローカルを残し再試行可能にし、失敗は通知する。

**課金・広告・プレミアム**
- プレミアム判定は `OneTimePurchaseService.isPremiumUnlocked`→`FeatureAccessControl` の一系統に集約（複製禁止）。最終ソースはサーバー（Firestore/レシート検証）で、SharedPreferences だけで最終判断しない。
- 広告はプレミアムで非表示。Web では広告・IAP を初期化せず（`kIsWeb` ガード維持）、Web 不可機能（カメラ・課金・広告）への導線も出さない。

**OCR・AI・Cloud Functions**
- AI/OCR 呼び出しに タイムアウト・`finally` でローディング解除・失敗 SnackBar・二重実行防止 を必ず実装。
- クライアントのタイムアウトはサーバー（`functions/index.js`）より長くし、変更は同PRで揃える。

**Web 制約**
- 横幅 800px 制限。ダイアログは `lib/utils/dialog_utils.dart` の `showConstrainedDialog`。

## テスト・CI

- **計算式・同期・移行・課金の変更は、先に失敗を再現するテストを書いてから実装。** バグ修正は再発防止テストを同PRに含める。
- ゲート: Codemagic=`flutter test --exclude-tags=integration`／GitHub Actions=Webデプロイ前に `flutter analyze`＋`flutter test`。テストをスキップ・削除して CI を通さない。
- 単一テスト `flutter test <path>`／CFデプロイ `cd functions && npm install && firebase deploy --only functions`。

## PR 前チェック

- [ ] `flutter analyze` エラー0・`flutter test` 全件パス（新規含む）
- [ ] 失敗系（オフライン・キャンセル・途中失敗）を確認
- [ ] UI変更はライト/ダーク両モード＋Web/モバイルで確認
- [ ] Web 影響なら `flutter build web` が通る
