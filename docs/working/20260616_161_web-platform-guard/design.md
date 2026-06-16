# Issue #161 設計書

## 修正方針

`dart:io` の `Platform` と `File` は Web では使用不可。`kIsWeb` で先に分岐し、Web 到達コードから除外する。

---

## Fix 1: `lib/services/app_info_service.dart`

### 現状
```dart
import 'dart:io' show Platform;  // line 5

// openAppStore() 内
if (Platform.isIOS) {   // Web でクラッシュ
  url = iosUrl;
}
```

### 修正
```dart
import 'package:flutter/foundation.dart' show kIsWeb;  // 追加

// openAppStore() 先頭に追加
if (kIsWeb) return;  // Web版ではストアリンク不要
```

---

## Fix 2: `lib/router.dart`

### 現状
```dart
GoRoute(
  path: '/camera',
  builder: (context, state) { ... },  // kIsWeb ガードなし
),
```

### 修正
```dart
import 'package:flutter/foundation.dart' show kIsWeb;

GoRoute(
  path: '/camera',
  redirect: (context, state) => kIsWeb ? '/' : null,  // Web は / にリダイレクト
  builder: (context, state) { ... },
),
```

---

## Fix 3: `lib/screens/main/widgets/bottom_summary_actions.dart`

### 現状
```dart
// build() の Row.children に無条件でカメラボタン
Consumer<FeatureAccessControl>(
  builder: (context, featureControl, _) {
    return Stack( ... カメラボタン ... );
  },
),
```

### 修正
```dart
import 'package:flutter/foundation.dart' show kIsWeb;

// カメラボタンを kIsWeb で非表示
if (!kIsWeb) ...[
  const SizedBox(width: 8),  // 前のSizedBoxも合わせて除外
  Consumer<FeatureAccessControl>(
    builder: (context, featureControl, _) {
      return Stack( ... );
    },
  ),
],
```

注意: SizedBox(width: 12) の位置関係を保持しつつレイアウト崩れがないよう確認する。
