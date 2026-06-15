---
version: "alpha"
name: "maikago"
description: "買いすぎ防止のための買い物リスト管理アプリ。やさしいパステル感を保ちつつ、買い物中に迷わず操作できる実用的なUIを優先する。"
colors:
  primary: "#FFC0CB"
  primary-soft: "#FFB6C1"
  secondary: "#FFE4E1"
  mint: "#B5EAD7"
  lavender: "#C7CEEA"
  accent: "#FFDAC1"
  background: "#FFFFFF"
  surface: "#FFFFFF"
  dark-background: "#1C1C1C"
  dark-surface: "#2B2B2B"
  text-primary: "#212121"
  text-secondary: "#757575"
  border-light: "#0000004D"
  border-dark: "#FFFFFF1A"
  error: "#E57373"
  success: "#81C784"
  warning: "#FFB74D"
  info: "#64B5F6"
typography:
  title:
    fontFamily: "App selected font"
    fontSize: "20px"
    fontWeight: 700
    lineHeight: 1.3
  body:
    fontFamily: "App selected font"
    fontSize: "16px"
    fontWeight: 400
    lineHeight: 1.5
  caption:
    fontFamily: "App selected font"
    fontSize: "13px"
    fontWeight: 400
    lineHeight: 1.4
rounded:
  input: "12px"
  card: "14px"
  dialog: "20px"
  button: "20px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "16px"
  lg: "24px"
  xl: "32px"
components:
  dialog:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.text-primary}"
    rounded: "{rounded.dialog}"
    padding: "24px"
  card:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.text-primary}"
    rounded: "{rounded.card}"
    padding: "16px"
  text-field:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.text-primary}"
    rounded: "{rounded.input}"
    padding: "12px"
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.background}"
    rounded: "{rounded.button}"
    padding: "12px"
  button-destructive:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.error}"
    rounded: "{rounded.button}"
    padding: "12px"
---

## Overview

まいカゴのUIは「かわいいが、買い物中に素早く使える」ことを優先する。主役は買い物リスト、合計金額、読み取り結果、設定項目であり、装飾は操作の邪魔をしない範囲に抑える。

新しい画面、ダイアログ、Widget、テーマ、色、余白、文字サイズを変更する前にこのファイルを読む。ここに書かれた値は、実装上は `lib/services/settings_theme.dart` の `SettingsTheme` / `AppColors`、共通UIは `CommonDialog` や `snackbar_utils.dart` を通して使う。

## Colors

色は直接 `Colors.red` や `Colors.white` のように書かず、原則として `Theme.of(context)` の `colorScheme`、`theme.cardColor`、`theme.dividerColor`、または既存の `AppColors` を使う。

- メイン操作: `colorScheme.primary`
- メイン操作上の文字・アイコン: `colorScheme.onPrimary`
- 通常テキスト: `colorScheme.onSurface`
- 補助テキスト: `colorScheme.onSurface.withValues(alpha: 0.6)`
- カード/ダイアログ背景: `theme.cardColor` または `colorScheme.surface`
- 区切り線: `theme.dividerColor`
- エラー/削除: `colorScheme.error`

テーマは pink, light, dark, orange, green, blue, beige, mint, lavender, purple, teal, amber, indigo, soda, coral を想定する。新規UIは特定テーマだけで見た目を固定せず、ライト系とダークテーマの両方で破綻しない作りにする。

## Typography

フォントと文字サイズはユーザー設定に従う。直接フォントファミリーや固定の大きな文字サイズを指定するより、`theme.textTheme` を優先する。

- 画面タイトル: `theme.textTheme.titleLarge` を基準にする。
- 本文: `theme.textTheme.bodyMedium` または `bodyLarge` を基準にする。
- 補足説明: `theme.textTheme.bodySmall` と補助テキスト色を使う。
- 重要な数値や合計金額は太字にしてよいが、色だけで意味を伝えない。

## Layout

画面は「必要な情報をすぐ読める」密度を優先する。買い物中の片手操作を想定し、主要アクションは画面下部やリスト近くに置く。

- 余白の基本単位は 8px / 16px / 24px。
- Web対応画面では既存方針どおり横幅を 800px 程度に制限する。
- カードを多用してページ全体を重くしない。繰り返し要素、設定項目、購入プランなど意味のある単位にだけ使う。
- テキストがボタンやカードからはみ出さないように、長い日本語文言は折り返しを前提にする。

## Elevation & Depth

影を強く使わず、背景色・カード色・区切り線・余白で階層を表現する。Material 3 の標準挙動と既存テーマを尊重し、独自の強いシャドウや派手なグラデーションは避ける。

## Shapes

既存の角丸を基準にする。

- ダイアログ: 20px
- ダイアログ内カード: 14px
- TextField: 12px
- ボタン: 20px

新しい角丸値を増やす場合は、既存コンポーネントでは表現できない理由があるときだけにする。

## Components

新規実装では既存の共通コンポーネントを優先する。

- ダイアログ: `lib/widgets/common_dialog.dart` の `CommonDialog`
- ダイアログ表示: `lib/utils/dialog_utils.dart` の `showConstrainedDialog`
- SnackBar: `lib/utils/snackbar_utils.dart`
- 数値入力: `lib/utils/input_formatters.dart` の `noLeadingZeroFormatter`
- テーマ: `lib/services/settings_theme.dart`

画面ごとに独自のボタン、独自のダイアログ、独自のSnackBarを作らない。必要な見た目が共通コンポーネントに足りない場合は、先に共通コンポーネントの拡張を検討する。

## Do's and Don'ts

Do:

- UI作業前に、この `DESIGN.md` と `CLAUDE.md` のUI関連ルールを確認する。
- `Theme.of(context)` と `ColorScheme` を使ってテーマ追従にする。
- ライトテーマとダークテーマの両方で読めるコントラストを保つ。
- 既存画面と同じ余白、角丸、ボタン、ダイアログ構造に寄せる。
- デザイン方針を変える変更では、この `DESIGN.md` も同時に更新する。

Don't:

- ページごとに新しい色、角丸、余白、ボタンスタイルを発明しない。
- 色のためだけに `isDark ? ... : ...` の分岐を新規追加しない。
- `ScaffoldMessenger` でSnackBarを直接構築しない。
- `Colors.red`, `Colors.black87`, `Colors.white70`, `Colors.grey.shade300` などを新規UIに直接書かない。
- 装飾目的だけの強いグラデーション、過度な影、過密なカードUIを追加しない。
