# GitHub Actions CI 整備 実装プラン

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** まいカゴに RoastPlus 同等の GitHub Actions CI（PR品質チェック・PRプレビュー・mainデプロイ強化）を導入する

**Architecture:** PR作成時に `pr-check.yml`（5ジョブ並列）でブロック、`firebase-hosting-pr.yml` でWebプレビュー発行、mainマージ時は `firebase-hosting-merge.yml` で品質チェック後に本番デプロイ。ブランチ保護で pr-check の全ジョブを必須とする。

**Tech Stack:** GitHub Actions、Flutter 3.41.4、subosito/flutter-action@v2、FirebaseExtended/action-hosting-deploy@v0、Gitleaks v8.30.0

**設計ドキュメント:** `docs/superpowers/specs/2026-06-16-github-actions-ci-design.md`

---

## ファイルマップ

| 操作 | ファイル | 内容 |
|---|---|---|
| 新規作成 | `.github/workflows/pr-check.yml` | PR品質チェック（5ジョブ並列） |
| 新規作成 | `.github/workflows/firebase-hosting-pr.yml` | PRプレビューデプロイ |
| 変更 | `.github/workflows/firebase-hosting-merge.yml` | analyze/test追加・バージョン固定 |

---

## Task 1: 既存Dartコードをフォーマット整形する

**背景:** `dart format` チェックをCIに入れる前に、既存コードを全て整形しておかないと最初のPRから全件赤になる。

**Files:**
- 変更: プロジェクト内の全 `.dart` ファイル（自動）

- [ ] **Step 1: フォーマットを適用する**

```bash
cd D:/Dev/maikago
dart format .
```

期待: 変更されたファイルの一覧が出力される（または "Formatted N files, N changed."）

- [ ] **Step 2: 差分を確認する**

```bash
git diff --stat
```

期待: `.dart` ファイルのみが変更されていること。ロジックの変更がないことを目視確認する（フォーマットは空白・改行のみ変更）。

- [ ] **Step 3: コミットする**

```bash
git add -A
git commit -m "style: dart format を一括適用（CI導入前の整形）"
```

---

## Task 2: pr-check.yml を作成する

**背景:** PRごとに5ジョブを並列実行し、全て通らないとマージできないようにする。

**Files:**
- 新規作成: `.github/workflows/pr-check.yml`

- [ ] **Step 1: ファイルを作成する**

`.github/workflows/pr-check.yml` を以下の内容で作成：

```yaml
name: PR Check

on:
  pull_request:
    branches: [main]

jobs:
  secrets-scan:
    name: Secrets Scan
    runs-on: ubuntu-latest
    steps:
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

  format:
    name: Format
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.41.4'
          channel: stable
          cache: true
      - name: Check dart format
        run: dart format --output=none --set-exit-if-changed .

  analyze:
    name: Analyze
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.41.4'
          channel: stable
          cache: true
      - name: Get dependencies
        run: flutter pub get
      - name: Create env.json placeholder
        run: echo '{}' > env.json
      - name: Flutter analyze
        run: flutter analyze --fatal-infos

  test:
    name: Test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.41.4'
          channel: stable
          cache: true
      - name: Get dependencies
        run: flutter pub get
      - name: Create env.json placeholder
        run: echo '{}' > env.json
      - name: Flutter test
        run: flutter test --exclude-tags=integration

  build:
    name: Build
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.41.4'
          channel: stable
          cache: true
      - name: Get dependencies
        run: flutter pub get
      - name: Create env.json placeholder
        run: echo '{}' > env.json
      - name: Flutter build APK
        run: flutter build apk --debug
```

- [ ] **Step 2: コミットする**

```bash
git add .github/workflows/pr-check.yml
git commit -m "ci: PR品質チェックワークフローを追加（analyze/test/build/format/secrets）"
```

---

## Task 3: firebase-hosting-pr.yml を作成する

**背景:** PR作成時にWebプレビューURLを発行し、PRコメントに自動投稿する。

**Files:**
- 新規作成: `.github/workflows/firebase-hosting-pr.yml`

- [ ] **Step 1: ファイルを作成する**

`.github/workflows/firebase-hosting-pr.yml` を以下の内容で作成：

```yaml
name: Deploy to Firebase Hosting on PR

on:
  pull_request:
    branches:
      - main

permissions:
  checks: write
  pull-requests: write

jobs:
  preview-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.41.4'
          channel: stable
          cache: true
      - run: flutter pub get
      - name: Create env.json placeholder
        run: echo '{}' > env.json
      - name: Flutter build web
        run: |
          flutter build web \
            --dart-define=FIREBASE_API_KEY=${{ secrets.FIREBASE_API_KEY }} \
            --dart-define=FIREBASE_APP_ID=${{ secrets.FIREBASE_APP_ID }} \
            --dart-define=FIREBASE_MESSAGING_SENDER_ID=${{ secrets.FIREBASE_MESSAGING_SENDER_ID }} \
            --dart-define=FIREBASE_PROJECT_ID=${{ secrets.FIREBASE_PROJECT_ID }} \
            --dart-define=FIREBASE_AUTH_DOMAIN=${{ secrets.FIREBASE_AUTH_DOMAIN }} \
            --dart-define=FIREBASE_STORAGE_BUCKET=${{ secrets.FIREBASE_STORAGE_BUCKET }} \
            --dart-define=FIREBASE_MEASUREMENT_ID=${{ secrets.FIREBASE_MEASUREMENT_ID }} \
            --dart-define=GOOGLE_WEB_CLIENT_ID=${{ secrets.GOOGLE_WEB_CLIENT_ID }} \
            --dart-define=ADMOB_INTERSTITIAL_AD_UNIT_ID=${{ secrets.ADMOB_INTERSTITIAL_AD_UNIT_ID }} \
            --dart-define=ADMOB_BANNER_AD_UNIT_ID=${{ secrets.ADMOB_BANNER_AD_UNIT_ID }} \
            --dart-define=ADMOB_APP_OPEN_AD_UNIT_ID=${{ secrets.ADMOB_APP_OPEN_AD_UNIT_ID }}
      - uses: FirebaseExtended/action-hosting-deploy@v0
        with:
          repoToken: ${{ secrets.GITHUB_TOKEN }}
          firebaseServiceAccount: ${{ secrets.FIREBASE_SERVICE_ACCOUNT_MAIKAGO2 }}
          projectId: maikago2
```

- [ ] **Step 2: コミットする**

```bash
git add .github/workflows/firebase-hosting-pr.yml
git commit -m "ci: PRプレビューデプロイワークフローを追加"
```

---

## Task 4: firebase-hosting-merge.yml を変更する

**背景:** mainへの直pushがあった場合の最終ゲートとして、既存のデプロイワークフローに analyze/test を追加する。また Flutter バージョンを固定する。

**Files:**
- 変更: `.github/workflows/firebase-hosting-merge.yml`

- [ ] **Step 1: ファイルを編集する**

`.github/workflows/firebase-hosting-merge.yml` を以下の内容に**全体置き換え**する：

```yaml
# Deploy Flutter web app to Firebase Hosting on merge to main
name: Deploy to Firebase Hosting on merge
on:
  push:
    branches:
      - main

permissions:
  contents: read
  checks: write

jobs:
  build_and_deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.41.4'
          channel: stable
          cache: true
      - run: flutter pub get
      - name: Create env.json placeholder
        run: echo '{}' > env.json
      - name: Flutter analyze
        run: flutter analyze --fatal-infos
      - name: Flutter test
        run: flutter test --exclude-tags=integration
      - name: Flutter build web
        run: |
          flutter build web \
            --dart-define=FIREBASE_API_KEY=${{ secrets.FIREBASE_API_KEY }} \
            --dart-define=FIREBASE_APP_ID=${{ secrets.FIREBASE_APP_ID }} \
            --dart-define=FIREBASE_MESSAGING_SENDER_ID=${{ secrets.FIREBASE_MESSAGING_SENDER_ID }} \
            --dart-define=FIREBASE_PROJECT_ID=${{ secrets.FIREBASE_PROJECT_ID }} \
            --dart-define=FIREBASE_AUTH_DOMAIN=${{ secrets.FIREBASE_AUTH_DOMAIN }} \
            --dart-define=FIREBASE_STORAGE_BUCKET=${{ secrets.FIREBASE_STORAGE_BUCKET }} \
            --dart-define=FIREBASE_MEASUREMENT_ID=${{ secrets.FIREBASE_MEASUREMENT_ID }} \
            --dart-define=GOOGLE_WEB_CLIENT_ID=${{ secrets.GOOGLE_WEB_CLIENT_ID }} \
            --dart-define=ADMOB_INTERSTITIAL_AD_UNIT_ID=${{ secrets.ADMOB_INTERSTITIAL_AD_UNIT_ID }} \
            --dart-define=ADMOB_BANNER_AD_UNIT_ID=${{ secrets.ADMOB_BANNER_AD_UNIT_ID }} \
            --dart-define=ADMOB_APP_OPEN_AD_UNIT_ID=${{ secrets.ADMOB_APP_OPEN_AD_UNIT_ID }}
      - uses: FirebaseExtended/action-hosting-deploy@v0
        with:
          repoToken: ${{ secrets.GITHUB_TOKEN }}
          firebaseServiceAccount: ${{ secrets.FIREBASE_SERVICE_ACCOUNT_MAIKAGO2 }}
          channelId: live
          projectId: maikago2
```

- [ ] **Step 2: コミットする**

```bash
git add .github/workflows/firebase-hosting-merge.yml
git commit -m "ci: mainデプロイワークフローにanalyze/testを追加・Flutterバージョン固定"
```

---

## Task 5: PRを出してCIが全グリーンになることを確認する

**背景:** ブランチ保護を設定する**前に**CIが通ることを確認する。通らない状態でブランチ保護を入れると自分がマージできなくなる。

**Files:** なし（確認作業）

- [ ] **Step 1: トピックブランチを作ってPRを出す**

```bash
git checkout -b ci/github-actions-setup
# Task 1〜4 のコミットがこのブランチにあることを確認
git log --oneline -5
```

すでに main に直コミットした場合は、現時点で新しいブランチを切って空コミットでPRを出す：
```bash
git checkout -b ci/verify-actions
git commit --allow-empty -m "ci: CIワークフロー動作確認用PR"
git push origin ci/verify-actions
gh pr create --title "ci: GitHub Actions CI動作確認" --body "ワークフローの動作確認用PR"
```

- [ ] **Step 2: GitHub の Actions タブで全ジョブがグリーンになることを確認する**

確認する項目：
- `PR Check` ワークフロー内の以下が全て ✅
  - Secrets Scan
  - Format
  - Analyze
  - Test
  - Build
- `Deploy to Firebase Hosting on PR` ワークフローでプレビューURLがPRコメントに投稿される

- [ ] **Step 3: 失敗ジョブがあれば原因を修正してコミット**

よくある失敗例：
- **Format 失敗**: Task 1 の `dart format .` が漏れていた → `dart format .` を再実行してコミット
- **Analyze 失敗**: `--fatal-infos` に引っかかる warning がある → `flutter analyze` をローカルで実行して確認し修正
- **Build 失敗**: `flutter build apk --debug` がエラー → エラーメッセージをローカルで再現して修正
- **Secrets Scan 失敗**: シークレットがコードに混入している → 該当箇所を修正

---

## Task 6: GitHub リポジトリ設定を行う

**背景:** CIが通ることを確認してから、ブランチ保護とその他推奨設定を入れる。

**Files:** なし（GitHub UIでの設定作業）

- [ ] **Step 1: ブランチ保護ルールを設定する**

GitHub → リポジトリ → Settings → Branches → "Add branch protection rule"

Branch name pattern: `main`

以下を設定する：

```
✅ Require a pull request before merging
   □ Require approvals: 0（変更不要）

✅ Require status checks to pass before merging
   ✅ Require branches to be up to date before merging

   Status checks の検索欄に以下を1つずつ入力して追加：
   - "Secrets Scan"
   - "Format"
   - "Analyze"
   - "Test"
   - "Build"

✅ Do not allow bypassing the above settings
```

"Save changes" をクリック。

> **注意:** Status checks の名前はワークフローの `jobs.<id>.name:` フィールドと完全一致する必要がある。
> Task 5 でPRを出して一度ジョブが走った後でないと検索欄に候補が出ない。

- [ ] **Step 2: PR マージ設定を変更する**

GitHub → Settings → General → "Pull Requests" セクション：

```
✅ Allow squash merging（これだけ ON）
□ Allow merge commits（OFF）
□ Allow rebase merging（OFF）
✅ Automatically delete head branches
```

"Save" をクリック。

- [ ] **Step 3: Dependabot を有効化する**

GitHub → Settings → Code security and analysis：

```
✅ Dependabot alerts → Enable
✅ Dependabot security updates → Enable
```

- [ ] **Step 4: 動作確認をする**

Task 5 で作ったPRを Squash merge して：
- main へのマージ後に `Deploy to Firebase Hosting on merge` が走ることを確認
- analyze/test ステップが通ることを確認
- Firebase Hosting の本番がデプロイされることを確認

---

## 完了条件チェックリスト

- [ ] `dart format --output=none --set-exit-if-changed .` がローカルでパスする（差分なし）
- [ ] PRを出すと `PR Check` の5ジョブが全て ✅ になる
- [ ] PRにWebプレビューURLのコメントが自動投稿される
- [ ] ブランチ保護が有効で、CIが通らないとマージボタンが押せない
- [ ] mainマージ後に `firebase-hosting-merge.yml` が analyze/test を含めて通る
- [ ] Issue #165 クローズ済み

---

## 対応 Issue

- Issue #165：flutter analyze と flutter test をデプロイ前に必ず通す
