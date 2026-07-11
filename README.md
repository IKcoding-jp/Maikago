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

Google Play でリリース済みの個人開発アプリです。企画・設計・実装・ストア公開・運用まですべて一人で行っています。

## なぜ作ったか

母が買い物のとき、予算内に収めるために電卓で計算しながらメモで買うものを確認する——その行き来を毎回していました。「リストに入れた瞬間に合計が見える一つのアプリ」があれば解決すると思ったのが開発のきっかけです。

## 主な機能

- **リアルタイム合計** — 個数・割引率を反映した合計を常時表示、予算オーバーを色で警告
- **カメラ OCR** — 値札を撮影すると商品名と税込価格を自動入力（Vision API + AI）
- **複数デバイス同期** — Google ログインでスマホ・タブレット間をリアルタイム同期
- **レシピ取り込み** — レシピ URL から材料を解析して一括追加
- **ゲストモード** — ログインなしで即利用開始、ログイン時にデータをクラウドへ安全に移行
- **買い切りプレミアム** — 広告非表示・リスト無制限（サブスクではなく買い切りを選択）

## 一人で回している開発サイクル

公開して終わりではなく、リリース後にコードベース全体を自己監査し、見つけた課題を Issue として公開・優先度管理しながら解消しています。

1. **監査** — データ消失・金額計算の誤差・同期の競合・課金の改竄耐性などの観点で全体を点検
2. **Issue 化** — 16 件の課題を [Issue（#154〜#169）](https://github.com/IKcoding-jp/Maikago/issues?q=is%3Aissue+is%3Aclosed) として公開し、高・中・低で優先度付け
3. **解消** — 再発防止テストを同じ PR に含める運用で、**全 16 件を対応完了**

「動くこと」と「安全であること」を分けて評価し、後者を計画的に潰す進め方をしています。

## 技術スタックとアーキテクチャ

| カテゴリ | 技術 | 選定理由 |
|----------|------|----------|
| フレームワーク | Flutter / Dart | 1コードベースで iOS / Android / Web に対応 |
| 状態管理 | Provider | アプリ規模に対して十分シンプル。過剰な抽象化を避けた |
| バックエンド | Firebase（Auth / Firestore / Functions / Hosting） | リアルタイムリスナー標準搭載で同期を少ないコードで実現 |
| AI・OCR | Cloud Vision API + OpenAI API | Cloud Functions 経由で API キーをクライアントに置かない |
| 課金・広告 | in_app_purchase / google_mobile_ads | 買い切りモデル。レシートはサーバー側で検証 |
| CI/CD | Codemagic + GitHub Actions | テスト・ビルド・TestFlight 配信・Web デプロイを自動化 |

```
┌─────────────────────────────────────────────────┐
│  UI Layer        Screens / Widgets / Dialogs    │
├─────────────────────────────────────────────────┤
│  State           Provider (Auth / Data / Theme) │
├──────────────┬──────────────────────────────────┤
│ Repositories │  Managers                        │
│ (CRUD)       │  (キャッシュ / リアルタイム同期)    │
├──────────────┴──────────────────────────────────┤
│  Services     Auth / OCR / IAP / Ads / Recipe   │
├─────────────────────────────────────────────────┤
│  Firebase     Firestore / Auth / Functions      │
└─────────────────────────────────────────────────┘
```

`DataProvider` をファサードとして、CRUD（Repository）・キャッシュと同期（Manager）・外部サービス連携（Service）に責務を分離しています。

## 技術的に工夫した点

**楽観的更新とロールバック** — 書き込み完了を待たずに UI を更新し、店内の不安定な回線でも操作感を損なわない設計。失敗時はキャッシュをロールバックして必ずユーザーに通知します。

**OCR パイプライン** — `カメラ → Cloud Functions（Vision API）→ AI（商品名整形・税込価格抽出）→ 確認画面` の多段構成。日本のスーパーの値札表記への調整をサーバー側に集約し、クライアント更新なしで認識精度を改善できます。

**課金のサーバー側レシート検証** — 購入レシートを Cloud Functions で Google Play / App Store のサーバー API と照合し、クライアント改竄でプレミアムを詐称できない構成にしています。

## セットアップ

```bash
git clone https://github.com/IKcoding-jp/Maikago.git
cd Maikago
flutter pub get
flutter run
```

Firebase を使う機能（同期・OCR・課金）には各自の Firebase プロジェクト設定と `--dart-define` での環境変数注入が必要です（`lib/env.dart` 参照）。設定なしでもゲストモードの基本機能は動作します。

## ライセンス

MIT License

---

**開発者**: IK — 母が電卓とメモを行き来しながら買い物する姿を見て、「一つのアプリになっていたら」と思って作りました。
