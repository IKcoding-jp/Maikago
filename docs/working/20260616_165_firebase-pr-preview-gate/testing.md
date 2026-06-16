# テスト計画

## ローカル検証
- `flutter analyze` → エラー0
- `flutter test --exclude-tags=integration` → 全件パス

## CI検証
- PRを作成し、`firebase-hosting-pr.yml` が analyze/test を通過することを確認
- （テスト失敗シナリオは手動CIトリガーで確認が理想だが、現実的には通過確認のみで可）
