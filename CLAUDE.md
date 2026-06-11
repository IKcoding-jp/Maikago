# CLAUDE.md

このファイルは Claude Code がこのリポジトリで作業する際の必須ルール。日本語で返答すること。

## プロジェクト概要

**まいカゴ** — 買い物中に合計金額をリアルタイム把握し、買いすぎを防ぐ買い物リストアプリ。
Flutter 製で iOS / Android / Web に対応し、Google Play でリリース済み。

バージョン・テーマ数などの可変情報はコードを正とする（`pubspec.yaml` の `version`、`lib/services/settings_theme.dart` のテーマ定義）。この文書に数値を固定しない。

主な機能: 買い物リスト、リアルタイム合計、カメラOCR、クラウド同期、共有タブ、レシピ取り込み、ゲストモード、プレミアム買い切り、広告表示。

## 最優先原則（すべての変更に優先する）

1. **ユーザーのデータを消さない。** ローカルデータの削除は、クラウド保存の成功を確認してからのみ行う。
2. **金額を間違えない。** 合計・割引・税の計算式を画面や Widget に直書きしない。
3. **失敗を隠さない。** 保存・同期・削除の失敗は必ずユーザーに通知する。`catch` して `debugPrint` だけで握りつぶすコードを書かない。
4. **Web で落とさない。** Web から到達可能なコードで `dart:io` を直接使わない。
5. **課金を欺かない。** 使用回数カウント・プレミアム判定は「ユーザーが得る価値」と厳密に一致させる。

## 作業前に必ず読む領域

| 触る機能 | 必ず先に読むファイル |
|---|---|
| 金額・合計・割引 | `lib/providers/managers/shared_tab_manager.dart`（`getDisplayTotal`）、`lib/models/list.dart` |
| アイテム/ショップ CRUD | `lib/providers/repositories/`（楽観的更新とロールバックの実装） |
| リアルタイム同期・共有タブ | `lib/providers/managers/realtime_sync_manager.dart`、`shared_tab_manager.dart` |
| 認証・ゲストモード | `lib/providers/auth_provider.dart`、`lib/providers/data_provider.dart`（`migrateGuestDataToCloud`） |
| 課金・広告 | `lib/services/one_time_purchase_service.dart`、`lib/services/feature_access_control.dart`、`lib/services/ad/` |
| OCR・レシピ | `lib/services/hybrid_ocr_service.dart`、`functions/index.js` |
| ルーティング | `lib/router.dart`（go_router。遷移は `context.push()`/`context.go()`） |
| UI規約・色・ダイアログ | `.claude/rules/dart-style.md`、`.claude/rules/ui-components.md` |
| セキュリティ | `.claude/rules/security.md`、`firestore.rules` |

## ドメインルール

### 金額計算（Issue #156 の再発防止）

- 合計・割引・税込の計算式を screens / widgets に直書きすることを**禁止**する。
- 計算は共通関数のみを使う。共通化（`lib/utils/` への集約）が完了するまでは `SharedTabManager.getDisplayTotal()` の式（`(price × quantity × (1 - discount)).round()`）を唯一の正とし、新規コードでも同じ関数を呼ぶこと。
- 丸めは「アイテム単位で1回」。単価で丸めてから加算する実装を新たに書かない。
- 計算式を変更したら、境界値テスト（割引50%×奇数価格×複数個 など）を必ず同じPRで追加・更新する。

### 入力値バリデーション（Issue #157）

- `discount` は 0.0〜1.0、`price`・`quantity` は 0 以上。**モデル境界（fromJson / copyWith）と入力UIの両方**で検証する。片方だけで済ませない。
- 数値入力UIは `lib/utils/input_formatters.dart` を使う。

### Firestore 同期・楽観的更新（Issue #154 / #158 / #164）

- 書き込みは楽観的更新（UI先行 → バックグラウンド保存）でよいが、**失敗時のロールバックとユーザー通知をセットで実装**する。通知のない楽観的更新は不完全な実装とみなす。
- 画面遷移後でも通知できるよう、`context.mounted` が false になりうる経路ではエラー表示手段を事前に確保する。`context.pop()` 後の非同期処理では `mounted` チェック必須。
- **Firestore から読むデータは壊れている前提で扱う。** fromJson はドキュメント単位で防御し、壊れた1件がリスト全体の読み込みを道連れにしない構造にする。
- 複数ドキュメントの一括更新・削除は、部分失敗時の整合性を必ず設計する（成功分と失敗分を区別してロールバック）。
- リアルタイム同期の Stream 購読中はバッチ更新でUI更新を抑制する。

### 共有タブ・共同編集（Issue #159 / #160）

- 複数ショップにまたがる更新は `WriteBatch` / transaction を第一候補にする。順次 `await` の連続更新を新たに書かない。
- 「最後に書いたものが常に正しい（last-write-wins）」を無条件に採用しない。競合時にどちらが勝つかを変更するときは、PR説明に競合シナリオ（2ユーザー同時編集）の挙動を明記する。
- 自分の書き込みのエコーバック保護（`pendingUpdates`）の時間窓を変更する場合は、書き込み遅延+配信遅延を考慮すること。

### ゲストモード・ログイン移行（Issue #154）

- `clearGuestData()` は**全件の移行成功を確認してからのみ**呼ぶ。部分失敗時はローカルデータを残し、再試行可能にする。
- 移行処理には二重実行ガードを設ける。移行の失敗はユーザーに通知する。

### 課金・広告・プレミアム判定（Issue #155 / #163）

- 使用回数のカウント（OCR等）は「ユーザーが価値を得た時点」でのみ増やす。キャンセル経路で消費しない。
- プレミアム判定は `OneTimePurchaseService.isPremiumUnlocked` → `FeatureAccessControl` の一系統に集約する。判定ロジックを別の場所に複製しない。
- 課金状態をクライアント保存（SharedPreferences）だけで最終判断しない。最終ソースはサーバー側（Firestore / レシート検証）とする。
- 広告はプレミアムで非表示。Web では広告・IAP を初期化しない（既存の `kIsWeb` ガードを維持）。

### OCR・AI・Cloud Functions の失敗時 UI（Issue #169）

- AI/OCR 呼び出しには必ず: タイムアウト、ローディング解除（`finally`）、失敗時の SnackBar 通知、二重実行防止を実装する。
- クライアントのタイムアウトはサーバー（`functions/index.js`）のタイムアウトより**長く**設定し、両者を変更するときは同じPRで揃える。
- API キーはクライアントに置かない。Cloud Functions + Secret Manager 経由のみ。環境変数は `lib/env.dart` の `Env` クラスで `--dart-define` から読む。

### iOS / Android / Web 差分（Issue #161）

- **Web から到達可能なファイルで `dart:io`（`Platform.isXX` / `File`）を直接使うことを禁止**する。`kIsWeb` を先に分岐するか、`defaultTargetPlatform` を使う。
- Web で使えない機能（カメラ・課金・広告）への導線は Web では出さない。
- Web の横幅は 800px に制限。ダイアログは `lib/utils/dialog_utils.dart` の `showConstrainedDialog` を使う。

## UI・コード規約

詳細は `.claude/rules/` を正とする（ここに重複記載しない）:

- 色・共通コンポーネント・ファイルサイズ → `.claude/rules/dart-style.md`
- ダイアログ・デザイン定数 → `.claude/rules/ui-components.md`
- セキュリティ → `.claude/rules/security.md`

要点のみ: ハードコード色禁止／ダイアログは `CommonDialog`／SnackBar は `snackbar_utils.dart` 経由／1ファイル500行で分割検討／同一ロジック2箇所で `lib/utils/` へ共通化／機能廃止時はコード・テスト・ドキュメントを全て削除する。

## テスト必須条件

- **大きな変更（計算式・同期・移行・課金）は、先に失敗を再現するテストを書いてから実装する。**
- 金額計算の変更 → 境界値テスト必須（丸め、割引0%/100%、数量複数）。
- 移行・同期の変更 → 失敗系テスト必須（途中失敗でデータが残ること）。
- バグ修正 → 再発防止テストを同じPRに含める。

```bash
flutter pub get                       # 依存関係
flutter analyze                       # 静的分析
flutter test                          # 全テスト実行
flutter test test/path/to_test.dart   # 単一テスト実行
flutter build web                     # Web ビルド
flutter build apk --debug             # Android APK

# Firebase Cloud Functions
cd functions && npm install && firebase deploy --only functions
```

## CI/CD で守るべき条件

- **Codemagic**（`codemagic.yaml`）: iOS/Android。`flutter test --exclude-tags=integration` がゲート。
- **GitHub Actions**（`.github/workflows/`）: Web の Firebase Hosting デプロイ（mainマージ時＋PRプレビュー）。`flutter analyze` と `flutter test` を**デプロイ前に必ず通す**（未整備の間は Issue #165 を参照し、ワークフロー変更時に必ず追加する）。
- テストをスキップ・削除してCIを通すことを禁止する。

## やってはいけない変更

- 金額計算式の Widget / 画面への直書き
- 失敗通知のない Firestore 書き込み・削除
- `clearGuestData()` を移行成功確認なしで呼ぶ変更
- Web 到達コードでの `dart:io` 直接使用
- 使用回数カウントをキャンセル経路で増やす変更
- Firestore ルールから `request.auth != null` を外す変更
- `debugPrint` へのユーザーデータ・トークン・APIキー出力
- README への手動統計値（リリース数・行数・期間・ファイル数）の追加
- 機能廃止時にコード・テスト・ドキュメントの一部だけ残すこと

## Issue 対応の作業手順

1. Issue の「原因（ファイル:行）」を読み、該当コードと上記「作業前に必ず読む領域」を確認する
2. 失敗を再現するテストを先に書く（再現不能なら Issue にコメントで報告）
3. 最小の修正を実装する（無関係なリファクタを混ぜない）
4. ライト/ダーク両モード・Web/モバイル両方で動作確認（UI変更時）
5. Issue の「完了条件」を1つずつ検証してから PR を作る

## PR 前チェックリスト

- [ ] `flutter analyze` がエラー0
- [ ] `flutter test` が全件パス（新規テスト含む）
- [ ] 失敗系（オフライン・キャンセル・途中失敗）の挙動を確認した
- [ ] UI変更ならライト/ダーク両モードで確認した
- [ ] Web ビルドに影響する変更なら `flutter build web` が通る
- [ ] 対応した Issue の完了条件をすべて満たしている
- [ ] 計算・同期・課金に触れた場合、対応するテストを追加した
