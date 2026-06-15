# GitHub Actions CI 整備 設計ドキュメント

作成日: 2026-06-16

## 概要

まいカゴ（Flutter モバイルアプリ）の GitHub Actions CI を整備する。
現状はWebデプロイワークフローのみで品質チェックがないため、RoastPlus と同レベルの厳格な CI を導入する。

## 前提・決定事項

| 項目 | 決定内容 |
|---|---|
| スコープ | PR品質チェック＋PRプレビュー＋mainデプロイ強化 |
| テスト失敗時のマージ | **ブロック**（ブランチ保護の必須チェック） |
| flutter analyze | `--fatal-infos`（警告もブロック） |
| dart format | **ブロック**（先に既存コードを整形してから導入） |
| Flutter バージョン | `3.41.4` に固定（Codemagic と統一） |
| ビルド確認 | `flutter build apk --debug`（モバイル優先。Webは任意） |
| PRプレビュー | Firebase Hosting プレビューチャンネル（maikago2） |
| PRプレビューのブロック対象 | **含めない**（Web は自分のみ使用のため） |

## ワークフロー全体像

```
トリガー                  ワークフロー                      何をする
────────────────────────────────────────────────────────────────────
PR作成・更新時  →  pr-check.yml              品質チェック（マージブロック対象）
PR作成・更新時  →  firebase-hosting-pr.yml   Webプレビューデプロイ（任意）
mainマージ時    →  firebase-hosting-merge.yml 品質チェック＋本番Webデプロイ
```

## ファイル別設計

### 1. `.github/workflows/pr-check.yml`（新規作成）

**トリガー:** `pull_request` （branches: [main]）

**ジョブ構成（全て並列）:**

| ジョブID | 名前 | 内容 | ブロック |
|---|---|---|---|
| `secrets-scan` | Secrets Scan | Gitleaks でシークレット漏洩チェック | ✅ |
| `format` | Format | `dart format --output=none --set-exit-if-changed .` | ✅ |
| `analyze` | Analyze | `flutter analyze --fatal-infos` | ✅ |
| `test` | Test | `flutter test --exclude-tags=integration` | ✅ |
| `functions-test` | Functions Unit Tests | `cd functions && npm test` | ✅ |
| `build` | Build | `flutter build apk --debug` | ✅ |

**共通設定:**
- Flutter バージョン: `3.41.4`（`subosito/flutter-action@v2` の `flutter-version` で固定）
- pub キャッシュ: `actions/cache` で `pubspec.lock` ハッシュをキーにキャッシュ
- `env.json`: `echo '{}' > env.json`（既存 merge ワークフローと同様）

**Secrets Scan ジョブ詳細:**
```yaml
- uses: actions/checkout@v4
  with:
    fetch-depth: 0
- name: Run Gitleaks on PR commits
  run: |
    docker run --rm \
      -v "$PWD:/repo" \
      -w /repo \
      ghcr.io/gitleaks/gitleaks:v8.30.0 \
      git --redact --no-banner --log-opts="origin/${{ github.base_ref }}..HEAD"
```

### 2. `.github/workflows/firebase-hosting-pr.yml`（新規作成）

**トリガー:** `pull_request` （branches: [main]）

**ジョブ構成:**

```
preview-deploy:
  - flutter pub get
  - echo '{}' > env.json
  - flutter build web（dart-define シークレット注入）
  - FirebaseExtended/action-hosting-deploy@v0（プレビューチャンネル）
    → PRコメントにプレビューURLを自動投稿
```

**パーミッション:**
```yaml
permissions:
  pull-requests: write
  checks: write
```

**設計判断:**
- `pr-check.yml` とは独立して動く。テスト失敗中でもプレビューURLが確認できる
- ブランチ保護の必須チェックには**含めない**（Web は自分のみ使用）

### 3. `.github/workflows/firebase-hosting-merge.yml`（既存を変更）

**変更内容:** `flutter pub get` の直後に以下2ステップを追加

```yaml
- name: Flutter analyze
  run: flutter analyze --fatal-infos

- name: Flutter test
  run: flutter test --exclude-tags=integration
```

**その他変更:**
- `subosito/flutter-action@v2` の `channel: stable` → `flutter-version: '3.41.4'` に変更

**目的:** main への直 push があった場合の最終ゲート（PR経由が通常だが念のため）

## GitHub リポジトリ設定

### ブランチ保護ルール

Settings → Branches → Add branch protection rule（対象: `main`）

```
✅ Require a pull request before merging
   ✅ Require approvals: 0（一人開発）

✅ Require status checks to pass before merging
   ✅ Require branches to be up to date before merging

   必須ステータスチェック（ジョブの name: と一致させる）:
   - Secrets Scan
   - Format
   - Analyze
   - Test
   - Functions Unit Tests
   - Build

✅ Do not allow bypassing the above settings
```

### その他推奨設定

**Settings → General → Pull Requests:**
```
✅ Automatically delete head branches（マージ後にブランチ自動削除）
✅ Allow squash merging のみ ON（merge commit / rebase は OFF）
```

**Settings → Code security:**
```
✅ Dependabot alerts
✅ Dependabot security updates
```

## 導入手順（推奨順序）

```
Step 1: dart format . を実行して既存コードを整形・コミット
Step 2: 3ワークフローファイルを作成・PRを出す
Step 3: CI が全ジョブグリーンになることを確認
Step 4: ブランチ保護ルールを設定（CI 確認後に設定するのが安全）
Step 5: Dependabot を有効化
```

## 対応 Issue

- Issue #165：`flutter analyze` と `flutter test` をデプロイ前に必ず通す（本設計で解消）
