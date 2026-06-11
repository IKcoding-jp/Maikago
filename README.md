# まいカゴ — 買い物中の「いくら使ったか」を見える化するアプリ

> カゴに入れた瞬間に合計がわかる。買いすぎを防ぐ買い物リストアプリ。

[![Flutter](https://img.shields.io/badge/Flutter-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-FFCA28?logo=firebase&logoColor=black)](https://firebase.google.com)
[![Platform](https://img.shields.io/badge/iOS%20%7C%20Android%20%7C%20Web-lightgrey)]()
[![Google Play](https://img.shields.io/badge/Google%20Play-414141?logo=google-play&logoColor=white)](https://play.google.com/store/apps/details?id=com.ikcoding.maikago&hl=ja)

<p align="center">
  <img src="docs/screenshots/login.png" width="180" />
  <img src="docs/screenshots/home.png" width="180" />
  <img src="docs/screenshots/camera.png" width="180" />
  <img src="docs/screenshots/recipe.png" width="180" />
</p>

Google Play でリリース済みの個人開発アプリです。企画・設計・実装・運用・ストア公開まで一人で行っています。

## 解決したかった課題

スーパーでの買い物には、小さくても毎回発生するストレスがあります。

- メモアプリと電卓を行き来しながら合計を暗算する
- レジに着くまで「予算内に収まっているか」がわからない
- 値札を見ながらの手入力が面倒で、結局リスト管理をやめてしまう
- 家族と「何を買うか」を共有する手段が LINE のメモになりがち

「リストに入れた瞬間に、割引と個数を反映した合計が見えていれば解決する」——これがこのアプリの出発点です。

## 提供している体験

| Before | After |
|---|---|
| 電卓とメモを往復して暗算 | アイテムをチェックすると割引・個数込みの合計が即時更新。予算超過は色で警告 |
| 値札を見ながら手入力 | 値札をカメラで撮影 → OCR + AI が商品名と税込価格を自動入力 |
| 家族との共有はメッセージアプリ頼み | 共有タブで同じリストをリアルタイム共同編集 |
| アプリ登録が面倒で使い始めない | ゲストモードで初回起動から即利用。ログイン時にデータをクラウドへ移行 |

## 主な機能

- **リアルタイム合計** — 個数・割引率を反映した合計を常時表示、予算オーバー警告
- **カメラ OCR** — 値札撮影から商品名・税込価格を自動認識（Vision API + ChatGPT）
- **クラウド同期** — Google ログインで複数デバイス間をリアルタイム同期
- **共有タブ** — 家族・パートナーとリストを共同編集
- **レシピ取り込み** — レシピ URL から材料を解析して一括追加
- **ゲストモード** — ログインなしで利用開始、ログイン時に安全にデータ移行
- **テーマ / フォント切替** — ライト・ダーク対応の多色テーマ
- **買い切りプレミアム** — 広告非表示・リスト無制限（サブスクではなく買い切りを選択）

## アーキテクチャ

```
┌─────────────────────────────────────────────────┐
│  UI Layer        Screens / Widgets / Dialogs    │
├─────────────────────────────────────────────────┤
│  State           Provider (Auth / Data / Theme) │
├──────────────┬──────────────────────────────────┤
│ Repositories │  Managers                        │
│ (CRUD)       │  (キャッシュ / リアルタイム同期 /   │
│              │   共有タブ)                       │
├──────────────┴──────────────────────────────────┤
│  Services     Auth / OCR / IAP / Ads / Recipe   │
├─────────────────────────────────────────────────┤
│  Firebase     Firestore / Auth / Functions      │
└─────────────────────────────────────────────────┘
```

`DataProvider` をファサードとして、CRUD（Repository）・キャッシュとリアルタイム同期（Manager）・外部サービス連携（Service）に責務を分離しています。

### 技術選定の理由

| 技術 | 理由 |
|------|------|
| Flutter | 1コードベースで iOS / Android / Web に対応。個人開発でのマルチプラットフォーム展開を現実的にする |
| Provider | このアプリの規模に対して十分シンプルな状態管理。過剰な抽象化を避けた |
| Cloud Firestore | リアルタイムリスナーが標準搭載で、共有タブの共同編集を少ないコードで実現できる |
| Cloud Functions | OCR / AI の API キーをクライアントに置かないための境界。レート制限もサーバー側で実施 |
| go_router | 認証状態によるリダイレクトを宣言的に一元管理 |

## 技術的に工夫した点

### 楽観的更新と競合制御

書き込み完了を待たずに UI を更新し、店内の不安定な回線でも操作感を損なわない設計です。失敗時はキャッシュをロールバックし、リアルタイム同期では自分の直近の書き込みをリモートスナップショットから保護する仕組み（pending 管理）を入れています。共同編集特有の「自分の編集が他人の古いデータで巻き戻る」問題には現在も改善を続けています（後述の Issue 参照）。

### OCR パイプライン

`カメラ → Cloud Functions（Vision API でテキスト抽出）→ ChatGPT（商品名整形・税込価格抽出）→ 確認画面` の多段構成。税込価格の優先認識など、日本のスーパーの値札表記に合わせた調整をサーバー側に集約し、クライアント更新なしで認識ロジックを改善できるようにしています。

### ゲスト→ログインのデータ移行

登録の手間で離脱させないため、まずローカルだけで完結するゲストモードで使い始められ、ログイン時にローカルデータをクラウドへ移行します。移行の安全性（部分失敗時のデータ保全）は重点的に改善している領域です。

### セキュリティ設計

API キーは `--dart-define` + Cloud Functions + Secret Manager で管理し、クライアントコードに置いていません。Firestore セキュリティルールは `request.auth.uid == userId` を基本とする最小権限で構成しています。

## 品質・安全性への取り組み

- **テスト**: モデル・Provider・課金制御・計算ロジックを対象にユニットテストを整備。バグ修正時は再発防止テストを同じ PR に含める運用
- **CI/CD**: Codemagic（iOS / Android のテスト・ビルド・TestFlight 配信）+ GitHub Actions（Web の自動デプロイと PR プレビュー）
- **静的解析**: `flutter_lints` ベースに `unawaited_futures` / `avoid_dynamic_calls` 等を追加した厳格設定
- **セルフ監査の公開**: データ消失・計算誤差・同期競合などの観点でコードベース全体を監査し、結果を [Issue（#154〜#169）](https://github.com/IKcoding-jp/Maikago/issues) として公開・優先度管理しています。「動くこと」と「安全であること」を分けて評価し、後者を計画的に潰す進め方をしています

## 今後の改善

監査で特定した課題を優先度順に対応しています（詳細は各 Issue）:

1. ゲストデータ移行の失敗時保全（[#154](https://github.com/IKcoding-jp/Maikago/issues/154)）と金額計算の一元化（[#156](https://github.com/IKcoding-jp/Maikago/issues/156)）
2. 書き込み失敗の確実な通知と一括操作の整合性（[#158](https://github.com/IKcoding-jp/Maikago/issues/158), [#159](https://github.com/IKcoding-jp/Maikago/issues/159)）
3. 共同編集の競合解決の改善（[#160](https://github.com/IKcoding-jp/Maikago/issues/160)）と購入レシートのサーバー検証（[#163](https://github.com/IKcoding-jp/Maikago/issues/163)）

## 技術スタック

| カテゴリ | 技術 |
|----------|------|
| フレームワーク | Flutter / Dart |
| 状態管理 | Provider |
| ルーティング | go_router |
| バックエンド | Firebase（Auth / Firestore / Cloud Functions / Hosting） |
| AI・OCR | Cloud Vision API + OpenAI API（Cloud Functions 経由） |
| 課金・広告 | in_app_purchase（買い切り）/ google_mobile_ads |
| CI/CD | Codemagic + GitHub Actions |
| テスト | flutter_test + mockito |

## プロジェクト構造

```
lib/
├── main.dart / router.dart   # エントリーポイント、ルーティング
├── models/                   # ドメインモデル
├── providers/                # 状態管理（ファサード + Repository + Manager）
├── services/                 # 認証 / OCR / 課金 / 広告 / テーマ 等
├── screens/                  # UI 画面
├── widgets/                  # 共通ウィジェット（CommonDialog 等）
└── utils/                    # SnackBar / ダイアログ / フォーマッタ
functions/                    # Cloud Functions（OCR・AI 処理）
```

## セットアップ

```bash
git clone https://github.com/IKcoding-jp/Maikago.git
cd Maikago
flutter pub get
flutter run
```

Firebase を使う機能（同期・OCR・課金）には、各自の Firebase プロジェクト設定（`google-services.json` / `GoogleService-Info.plist`）と `--dart-define` での環境変数注入が必要です（`lib/env.dart` 参照）。設定なしでもゲストモードの基本機能は動作します。

## 注意事項

- 個人開発・運用のアプリです。Issue / Pull Request を歓迎します
- OCR / AI 機能は Cloud Functions のデプロイと API キー設定が前提です
- バージョンは `pubspec.yaml`、変更履歴はリリースタグを参照してください

## ライセンス

MIT License

---

**開発者**: IK — スーパーで電卓とメモを行ったり来たりするのが面倒で、自分が欲しかったから作りました。
