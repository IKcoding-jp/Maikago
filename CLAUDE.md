# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

日本語で返答してください。

## 起動時・/clear 後に読むコンテキスト

このリポジトリは、判断基準を 3 つの永続ドキュメントに分離している。CLAUDE.md は運用の入口であり、詳細はそれぞれの正本を読むこと。

| いつ読むか | ファイル | 役割（正本） |
|-----------|---------|------------|
| 新機能・仕様・課金・共有・削除に関わる時 | `docs/context/PRODUCT.md` | 何を作る / 作らないか（中心価値・非目標・判断チェックリスト） |
| 複数ファイル・状態管理・同期・ルーティング・Firestore・OCR に関わる時 | `docs/context/ARCHITECTURE.md` | どこに / どの層に実装するか（依存方向・責務・データフロー） |
| 画面・ダイアログ・色・余白・文字サイズに関わる時 | `docs/context/DESIGN.md` | どう見せるか（色・タイポ・角丸・共通コンポーネント） |

- 文書と既存コードが矛盾したら、**まず既存コードを正とし**、方針変更が必要な時だけ理由を添えて該当 doc も更新する。

## プロジェクト概要

**まいカゴ** — 買い物中に合計金額を把握し「買いすぎ」を防ぐ買い物リストアプリ（Flutter / iOS・Android・Web）。
バージョンは `pubspec.yaml` の `version` を正とする。Dart SDK `>=3.0.0 <4.0.0`。Firebase Project ID: `maikago2`。

## よく使うコマンド

```bash
flutter pub get                         # 依存関係
flutter analyze                         # 静的分析（Dart 変更後は必須）
flutter test                            # 全テスト
flutter test test/path/to_test.dart     # 単一テスト
flutter test --name "<test name>"       # テスト名で絞り込み実行
flutter build web                       # Web ビルド（Web 影響時に確認）
flutter build apk --debug               # Android（デバッグ）

# Firebase Cloud Functions
cd functions && npm install && firebase deploy --only functions
```

mockito を使うテストでモックを再生成する場合: `dart run build_runner build --delete-conflicting-outputs`

## アーキテクチャ要約

Provider パターン。UI から Firestore / Cloud Functions / 外部 API を**直接呼ばない**。依存は一方向:

```text
Screens / Widgets / Dialogs
  -> Providers (auth / data / theme)
    -> Repositories (item, shop CRUD) / Managers (cache, realtime sync, shared tab)
      -> Services (auth, OCR, recipe, purchase, theme ...)
        -> Firebase / Cloud Functions / Platform APIs
```

- `lib/main.dart` — Firebase 初期化・`MultiProvider` 注入。`lib/router.dart` — go_router ルート定義と認証リダイレクト（遷移は `context.push()` / `context.go()`）。
- `lib/providers/data_provider.dart` は**ファサード**。ロジックを直接足す前に Repository / Manager / Service のどこに置くか判断する（肥大化注意）。
- OCR・AI・課金など秘密情報を伴う処理は Cloud Functions（`functions/index.js`, Node.js 20 / Functions v2）側に寄せる。
- 詳細な層責務・データフロー（買い物リスト操作 / OCR / レシピ取り込み）は `docs/context/ARCHITECTURE.md`。

## 実装時に必ず守るガード

詳細な色表・コンポーネント一覧は `docs/context/DESIGN.md`。ここでは「外してはいけない原則」だけ示す。

- **ハードコード色禁止。** `Colors.red` / `Colors.black87` / `Colors.white70` / `Colors.grey.shade300` を新規 UI に直接書かない。`colorScheme` / `theme.cardColor` / `theme.dividerColor` / 既存 `AppColors` を使う。色のために `isDark ? X : Y` の分岐を画面側に増やさない（テーマ側で吸収）。新規 UI はライト・ダーク両方で確認。テーマは `lib/services/settings_theme.dart` の `SettingsTheme.generateTheme()` が 14 種を動的生成。
- **共通コンポーネント必須。** 画面ごとに独自実装しない:
  - ダイアログ → `CommonDialog`（`lib/widgets/common_dialog.dart`）/ 表示は `showConstrainedDialog`（`lib/utils/dialog_utils.dart`, Web 横幅制限付き）
  - SnackBar → `lib/utils/snackbar_utils.dart`（`ScaffoldMessenger` 直接構築禁止）
  - 数値入力 → `lib/utils/input_formatters.dart` の `noLeadingZeroFormatter`
- **非同期と状態管理。** Firestore 書き込みは楽観的更新（UI 即時更新 → バックグラウンド書き込み、失敗は SnackBar で通知）。非同期処理後に `BuildContext` を使う時は `mounted` チェック必須（特に `context.pop()` 後）。`use_build_context_synchronously` は lint 有効。
- **セキュリティ。** API キーをクライアント（`lib/`）に置かない（`--dart-define` + Cloud Functions + Secret Manager）。`debugPrint` にユーザーデータ・トークン・鍵を含めない。Firestore ルールは `request.auth.uid == userId` の最小権限。
- **マネタイズ。** 課金・広告は `OneTimePurchaseService` と `FeatureAccessControl` で制御（プレミアムで広告非表示）。
- **コード構造。** 1 ファイル 500 行超で責務分割を検討。同ロジックが 2 箇所以上に出たら `lib/utils/` / 共通 Widget / Service に共通化。機能廃止時はコード・テスト・ドキュメントを残さず全削除。
- **Web 対応。** `kIsWeb` で分岐し、横幅は 800px 程度に制限。

## 変更後の検証

- Dart/Flutter 変更 → `flutter analyze`（必須）。テストに関わる変更 → `flutter test`（範囲が狭ければ単一テスト）。
- Web 影響 → `flutter build web`。Functions 変更 → `functions/` に `npm test` があるか確認、なければ対象関数の手動確認手順を示す。
- Firestore ルール変更 → ルールテストまたは最小権限の手動確認。

## 環境変数

`lib/env.dart` の `Env` クラスで管理。`--dart-define`（CI/CD）を優先し `env.json` にフォールバック（`env.json` は廃止移行済み）。ローカルは `env.json.example` 参照。

## CI/CD

- **Codemagic**（`codemagic.yaml`）: iOS Simulator Test / Android Build / iOS Release（TestFlight 配信）。リリースブランチ起点。
- **GitHub Actions**（`.github/workflows/`）: main マージで Firebase Hosting デプロイ、PR でプレビュー。
