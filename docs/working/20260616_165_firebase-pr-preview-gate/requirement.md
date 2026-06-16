# Issue #165 要件定義

## 問題
PRプレビューデプロイ（`firebase-hosting-pr.yml`）に
`flutter analyze` / `flutter test` が存在せず、
テストが失敗した状態でもプレビューがデプロイされてしまう。

## 完了条件
- [ ] `flutter test` 失敗時にPRプレビューデプロイが中断される
- [ ] `flutter analyze` 失敗時にPRプレビューデプロイが中断される

## 現状（調査結果）
| ワークフロー | analyze | test | 状態 |
|---|---|---|---|
| `firebase-hosting-merge.yml` | ✅ あり | ✅ あり | 解決済み（commit 135234d1） |
| `firebase-hosting-pr.yml` | ❌ なし | ❌ なし | 未対応 ← 今回の対象 |
| `pr-check.yml` | ✅ あり | ✅ あり | PRチェック専用（deploy前ゲートにはなっていない） |
