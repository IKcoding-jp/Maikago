# 購入サーバー検証のセットアップ手順（Issue #163）

クライアント改竄によるプレミアム不正取得を防ぐため、購入レシートを
Cloud Functions（`verifyPurchase`）でサーバー検証する仕組みを追加した。
コードは実装・テスト済みだが、**本番で動かすには以下の手動作業が必要**。

## 全体像

```
アプリ（購入成功）
  → verifyPurchase(platform, productId, purchaseToken)  ← Cloud Function
      → Google Play Developer API で購入トークンを検証
      → 検証OKなら users/{uid}/purchases/premium_entitlement に isPremium:true を書込
          （このドキュメントは Firestore ルールでクライアント書込禁止 = サーバー専用）
アプリ（起動時）
  → premium_entitlement を読んでプレミアム判定（信頼できる唯一のソース）
```

## 手動作業（IK が実施）

### 1. Google Cloud サービスアカウントの用意

1. Firebase プロジェクトの GCP コンソール → IAM と管理 → サービスアカウント。
2. サービスアカウントを新規作成（例: `play-purchase-verifier`）。
   - 既存の Functions 実行用 SA を使い回さず、専用 SA を推奨。
3. そのサービスアカウントの **JSON 鍵** を作成・ダウンロード。

### 2. Google Play Console 側で権限付与

1. [Google Play Console](https://play.google.com/console) → 「ユーザーと権限」。
2. 上記サービスアカウントのメールアドレスを招待。
3. アプリ権限で以下を付与（購入状態の参照に必要）:
   - 「財務データ、注文、キャンセル調査レポートを表示」
   - （または「注文と定期購入を管理」）
4. Google Cloud コンソールで **Google Play Android Developer API** を有効化。

> 反映に最大24〜48時間かかることがある。

### 3. Secret Manager に鍵を登録

ダウンロードした JSON 鍵の中身を、シークレット名 `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` で登録する。

```bash
# 例: JSONファイルからシークレットを作成
firebase functions:secrets:set GOOGLE_PLAY_SERVICE_ACCOUNT_JSON
# プロンプトに JSON 全文を貼り付け（または < でファイルを流し込む）
```

### 4. デプロイ

```bash
# Cloud Functions（verifyPurchase を含む）
cd functions
npm install
firebase deploy --only functions

# Firestore ルール（premium_entitlement をサーバー専用書込にする）
cd ..
firebase deploy --only firestore:rules
```

## 動作確認

- 実機（Android）で購入 → プレミアムが有効になること。
- Functions ログに「購入検証成功・エンタイトルメント付与」が出ること。
- Firestore で `users/{uid}/purchases/premium_entitlement` が作成され、
  クライアントからは書き込めない（ルールで拒否される）こと。
- 既存のプレミアム購入者: アプリ起動時に自動で `restorePurchases` が走り、
  サーバー再検証 → `premium_entitlement` 付与でシームレスに移行する。

## 既知の制約・TODO

- **iOS は未対応**。`verifyPurchase` は iOS に対して `unimplemented` を返す。
  iOS リリース時に App Store Server API（JWT署名）で同等の検証を実装し、
  `_handleSuccessfulPurchase` の iOS 分岐をサーバー検証必須に切り替える。
  現状 iOS はクライアント一次検証（`PurchaseValidator`）のみで付与している。
- **Firestore ルールの emulator テスト**（`test/firestore_rules/purchases.test.js`）は
  **JDK 21 以上が必要**。ローカルが JDK 17 の場合は実行できない（CI / JDK21+ 環境で実行）。

## 関連ファイル

| 役割 | ファイル |
|---|---|
| Android 検証ロジック（純粋・テスト済み） | `functions/purchase/android_verifier.js` |
| Play API グルー（googleapis） | `functions/purchase/android_publisher_client.js` |
| Cloud Function 本体 | `functions/index.js`（`exports.verifyPurchase`） |
| Firestore ルール | `firestore.rules`（`premium_entitlement` 保護） |
| クライアント検証ラッパー | `lib/services/purchase/purchase_verifier.dart` |
| 購入処理・移行 | `lib/services/one_time_purchase_service.dart` |
