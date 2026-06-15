# ARCHITECTURE.md

このファイルは、まいカゴの技術構造と実装判断を復元するための永続コンテキストです。複数ファイル変更、状態管理、データ同期、ルーティング、Firestore、Cloud Functions、課金、OCR、共有機能に関わる作業では、実装前にこのファイルを読んでください。

## System Overview

まいカゴは Flutter マルチプラットフォームアプリです。Provider パターンを中心に、画面、Provider、Repository/Manager、Service、Firebase の層で構成します。

基本の依存方向は次の通りです。

```text
Screens / Widgets / Dialogs
  -> Providers
    -> Repositories / Managers
      -> Services
        -> Firebase / Cloud Functions / Platform APIs
```

UI層から Firestore や Cloud Functions を直接扱う実装は避けます。既存の Provider、Repository、Manager、Service のどこに責務があるかを確認してから変更します。

## Application Layers

### Entry Point

- `lib/main.dart`
  - Firebase初期化
  - Provider注入
  - アプリ全体の起動設定

- `lib/router.dart`
  - go_router によるルート定義
  - 認証状態に応じたリダイレクト
  - 画面遷移の中心

画面遷移は既存方針に合わせ、原則として `context.push()` / `context.go()` を使います。

### UI Layer

- `lib/screens/`
  - 画面単位のUI
  - `main_screen.dart` がメイン画面
  - `screens/main/` にメイン画面の dialogs / widgets / utils を分割

- `lib/widgets/`
  - 複数画面で再利用する共通Widget
  - ダイアログは `CommonDialog` を優先

- `lib/utils/`
  - SnackBar、入力フォーマッタ、ダイアログ表示、レスポンシブ補助など

UIは `DESIGN.md` に従います。色、角丸、余白、ダイアログ、SnackBarを画面ごとに独自実装しないでください。

### State Management Layer

- `lib/providers/auth_provider.dart`
  - 認証状態

- `lib/providers/data_provider.dart`
  - 買い物リストデータのファサード
  - UIから見た主要なデータ操作入口
  - 内部処理は Repository / Manager に委譲する

- `lib/providers/theme_provider.dart`
  - 選択テーマ、フォント、文字サイズなど

- `lib/providers/repositories/`
  - `item_repository.dart`: アイテムCRUD
  - `shop_repository.dart`: ショップ/リストCRUD

- `lib/providers/managers/`
  - `data_cache_manager.dart`: キャッシュ管理
  - `realtime_sync_manager.dart`: Firestoreリアルタイム同期
  - `shared_tab_manager.dart`: 共有タブ管理

`DataProvider` は肥大化しやすいため、直接ロジックを追加する前に、Repository / Manager / Service のどこに置くべきか判断します。

### Service Layer

- `lib/services/auth_service.dart`
  - 認証処理

- `lib/services/data_service.dart` と `lib/services/data/`
  - Firestoreデータ操作のサービス層

- `lib/services/hybrid_ocr_service.dart`
  - OCR/AI解析の統合

- `lib/services/vision_ocr_service.dart`
  - Vision API系OCR処理

- `lib/services/cloud_functions_service.dart`
  - Cloud Functions 呼び出し

- `lib/services/recipe_parser_service.dart`
  - レシピ解析

- `lib/services/camera_service.dart`
  - カメラ操作

- `lib/services/one_time_purchase_service.dart`
  - 買い切り課金

- `lib/services/feature_access_control.dart`
  - プレミアム状態による機能制御

- `lib/services/settings_theme.dart`
  - テーマ生成と色定義

APIキー、AI処理、OCRなどの外部サービス連携は、クライアントに秘密情報を置かず Cloud Functions 側へ寄せます。

### Firebase Cloud Functions

- `functions/index.js`
  - OCR、画像解析、AI連携などサーバー側処理

Cloud Functions は Node.js 20 / Firebase Functions v2 API を前提にします。秘密情報は Secret Manager で扱い、FlutterクライアントにAPIキーを含めません。

## Data Flow

### 通常の買い物リスト操作

```text
User action
  -> Screen / Dialog
  -> DataProvider
  -> ItemRepository or ShopRepository
  -> DataService / Firestore
  -> RealtimeSyncManager
  -> UI update
```

Firestore書き込みは、既存方針どおり楽観的更新を優先します。ユーザー体験を止めず、失敗時はSnackBarなどで分かりやすく伝えます。

### OCR操作

```text
Camera screen
  -> CameraService
  -> CloudFunctionsService / HybridOcrService
  -> Cloud Functions
  -> Vision API / AI processing
  -> OCR result confirmation screen
  -> DataProvider
  -> Firestore
```

OCRやAIの結果はそのまま確定せず、確認・編集できる画面を経由します。

### Recipe Import

```text
Recipe URL input
  -> RecipeParserService
  -> Confirmation UI
  -> DataProvider
  -> Firestore
```

レシピ解析結果も、ユーザーが確認・編集してから買い物リストへ追加します。

## Architecture Rules

- UI層から Firestore、Cloud Functions、外部APIを直接呼ばない。
- 画面はProviderを通じて状態を読み書きする。
- `DataProvider` に大きな処理を追加する前に、Repository / Manager / Service への分離を検討する。
- 既存のディレクトリ構成と命名に合わせる。
- 1ファイル500行を超える場合は責務分割を検討する。
- 同じロジックが2箇所以上に出たら `lib/utils/`、共通Widget、Serviceへの共通化を検討する。
- Web対応が必要なUIでは `kIsWeb` と既存レスポンシブ方針を確認する。
- 非同期処理後に `BuildContext` を使う場合は `mounted` を確認する。
- `context.pop()` 後の非同期処理では特に `mounted` とUI更新タイミングに注意する。

## UI Architecture Rules

- UI作業では `DESIGN.md` を読む。
- ダイアログは `CommonDialog` を優先する。
- SnackBarは `snackbar_utils.dart` の関数を使う。
- Web横幅制限付きダイアログは `showConstrainedDialog` を使う。
- テーマ色は `Theme.of(context).colorScheme`、`theme.cardColor`、`theme.dividerColor`、既存 `AppColors` を使う。
- 色のためだけに画面側でダークモード分岐を増やさない。

## Product Boundary Rules

仕様判断に迷ったら `PRODUCT.md` を読む。まいカゴの中心価値は、買い物中に合計金額を把握し、買いすぎを防ぐことです。

次のような変更は、実装前に目的と範囲を明確にしてください。

- 課金、広告、プレミアム制限
- データ削除、共有、同期
- OCR/AI解析結果の自動確定
- Firestoreルール
- APIキーやSecret Manager
- 既存データ形式の変更

## Testing and Verification

変更後は、影響範囲に応じて検証します。

- Dart/Flutterコード変更: `flutter analyze`
- 既存テストに関わる変更: `flutter test`
- 単一テストで十分な変更: `flutter test test/path/to_test.dart`
- Webビルド影響: `flutter build web`
- Functions変更: `cd functions && npm test` が存在するか確認し、なければ対象関数の手動確認手順を示す
- Firestoreルール変更: ルールテストまたは最小権限の手動確認を行う

TDDを行う場合は、先に期待動作をテストまたは手動確認項目として書き、失敗を確認してから実装します。AIにTDDを指示するだけでなく、どの仕様にどのテストが対応するかを明確にしてください。

## Documentation Rules

- UI方針を変えたら `DESIGN.md` を更新する。
- プロダクト方針を変えたら `PRODUCT.md` を更新する。
- 層構造、依存方向、主要サービス責務を変えたら `ARCHITECTURE.md` を更新する。
- 大きな機能では `docs/working/` または `docs/plans/` の既存形式に合わせて仕様・タスク・検証記録を残す。
- Superpowersを使う場合は、Superpowersが生成するspec/plan/tasklistを優先し、このファイル群はプロジェクト固有の判断基準として参照する。
