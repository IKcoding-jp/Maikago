# Issue #161 タスクリスト

**ステータス**: 進行中
**作業ブランチ**: fix/#161-web-platform-guard

## Phase 1: 調査

- [x] Issue #161 内容確認
- [x] `app_info_service.dart` の Platform.isIOS 使用箇所確認
- [x] `router.dart` の /camera ルート確認
- [x] `bottom_summary_actions.dart` の dart:io 使用箇所確認

## Phase 2: 実装

- [x] `lib/services/app_info_service.dart` に kIsWeb ガード追加
- [x] `lib/router.dart` の /camera ルートに kIsWeb リダイレクト追加
- [x] `lib/screens/main/widgets/bottom_summary_actions.dart` のカメラボタンを Web で非表示

## Phase 3: 検証

- [ ] `flutter analyze` パス
- [ ] `flutter test` パス
