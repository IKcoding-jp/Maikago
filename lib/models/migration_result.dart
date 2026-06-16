// ゲスト→ログイン移行の結果を表す不変オブジェクト。
// auth_provider と data_provider のどちらからも参照できるよう、
// 業務ロジック層に依存しない models/ に配置する。

/// ゲストデータの Firestore 移行結果。
///
/// 成功件数・失敗件数を保持し、呼び出し側（UI）が
/// 「全件成功か」「一部失敗か」を判定して通知できるようにする。
class MigrationResult {
  const MigrationResult({
    this.migratedShops = 0,
    this.migratedItems = 0,
    this.failedShops = 0,
    this.failedItems = 0,
  });

  /// クラウドへ保存できたショップ数（今回実行分）
  final int migratedShops;

  /// クラウドへ保存できたアイテム数（今回実行分）
  final int migratedItems;

  /// 保存に失敗したショップ数
  final int failedShops;

  /// 保存に失敗したアイテム数
  final int failedItems;

  /// 移行対象が無く、何もしなかった結果。
  static const MigrationResult empty = MigrationResult();

  /// 失敗が1件も無い（全件成功）か。
  bool get isComplete => failedShops == 0 && failedItems == 0;

  /// 1件以上失敗したか。
  bool get hasFailures => !isComplete;

  /// 失敗した総件数（ショップ＋アイテム）。
  int get failedCount => failedShops + failedItems;

  /// 今回移行した総件数（ショップ＋アイテム）。
  int get migratedCount => migratedShops + migratedItems;

  /// 移行対象が存在せず、成功も失敗も無かったか。
  bool get isNothingToMigrate =>
      migratedShops == 0 &&
      migratedItems == 0 &&
      failedShops == 0 &&
      failedItems == 0;

  @override
  String toString() =>
      'MigrationResult(migratedShops: $migratedShops, migratedItems: $migratedItems, '
      'failedShops: $failedShops, failedItems: $failedItems)';
}
