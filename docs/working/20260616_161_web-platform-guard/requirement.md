# Issue #161 要件定義: Web版 dart:io Platform クラッシュ修正

## 問題

Web版で以下の操作をするとランタイムエラー（`UnsupportedError`）が発生してクラッシュする。
- 設定画面 / アプリ情報画面でストアリンクをタップ
- カメラ画面へ遷移（導線ガードなし）

## 根本原因

| ファイル | 行 | 問題 |
|---|---|---|
| `lib/services/app_info_service.dart` | 5, 102 | `import 'dart:io' show Platform` + `Platform.isIOS` を `kIsWeb` ガードなしで使用 |
| `lib/router.dart` | 0, 234 | `import 'dart:io'` + `/camera` ルートに `kIsWeb` リダイレクトなし |
| `lib/screens/main/widgets/bottom_summary_actions.dart` | 2, 96 | `import 'dart:io'` + カメラボタンを Web でも表示 |

## 完了条件

- [ ] `flutter build web` 後、設定/アプリ情報画面の全タップ操作でクラッシュしない
- [ ] Web でカメラ・OCR撮影への導線が非表示になっている
- [ ] `flutter analyze` がパス
- [ ] `flutter test` がパス
