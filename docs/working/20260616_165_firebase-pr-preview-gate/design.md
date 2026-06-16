# 設計書

## 変更対象ファイル
`.github/workflows/firebase-hosting-pr.yml`

## 変更内容
`env.json` 作成ステップの直後・`flutter build web` の直前に2ステップを追加:

```yaml
- name: Flutter analyze
  run: flutter analyze --fatal-infos
- name: Flutter test
  run: flutter test --exclude-tags=integration
```

## 参考: merge ワークフロー（L25-28）
```yaml
- name: Flutter analyze
  run: flutter analyze --fatal-infos
- name: Flutter test
  run: flutter test --exclude-tags=integration
```
同じステップをそのまま使用する（一貫性のため）。

## なぜ pr-check.yml に依存しないか
GitHub Actions では別ワークフロー間の `needs:` が使えない。
プレビューデプロイを自律的にゲートする最もシンプルな方法は
ワークフロー内にステップを直接追加すること。
