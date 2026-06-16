# Firestore セキュリティルールの emulator テスト

`firestore.rules` の挙動を Firebase エミュレータ上で検証するユニットテスト。
Flutter の `flutter test`（Dart）とは別系統で、Node.js + `@firebase/rules-unit-testing` を使う。

## 対象

- `families/{familyId}` の読み取り/更新メンバー判定（Issue #162）
  - `memberIds`（UID文字列の配列）による人数無制限のメンバー判定
  - 旧データ（配列形式・最大10人）の回帰がないこと

## 前提

- Node.js 18 以上
- **JDK 21 以上**（Firestore エミュレータの実行に必要。`firebase-tools` 15 系の要件）
  - 例: `JAVA_HOME` を JDK 21+ に向ける

## 実行方法

```bash
cd test/firestore_rules
npm install

# エミュレータを起動してテストを実行（推奨）
npm run test:emulator
```

`test:emulator` は `firebase emulators:exec` で Firestore エミュレータを一時起動し、
その中で `npm test`（mocha）を実行する。リポジトリルートの `firebase.json` の
`firestore.rules` と `emulators.firestore`（ポート 8080）を使用する。

### 既にエミュレータが起動している場合

別途 `firebase emulators:start --only firestore` 済みなら、テストだけ実行できる:

```bash
cd test/firestore_rules
npm test
```

## メモ

- `node_modules/` と `package-lock.json` は `.gitignore` 済み。
- CI への組み込みは未対応（Issue #165 のワークフロー整備時に検討）。
