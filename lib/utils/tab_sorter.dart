import 'package:maikago/models/shop.dart';

/// タブの並び順を管理するユーティリティクラス
class TabSorter {
  /// 共有タブごとにタブを隣接させる並び順を生成
  ///
  /// 並び順のルール:
  /// 1. 共有タブごとにグループ化
  /// 2. 各グループ内では作成日時順（古い順）
  /// 3. 共有していないタブは最後に配置
  /// 4. 同じグループのタブは隣接して表示
  static List<Shop> sortShopsBySharedTabs(List<Shop> shops) {
    if (shops.isEmpty) return shops;

    // 1. 共有タブごとに分類
    final Map<String, List<Shop>> sharedTabGroups = {};
    final List<Shop> unsharedShops = [];

    for (final shop in shops) {
      if (shop.sharedTabGroupId != null) {
        final groupId = shop.sharedTabGroupId!;
        if (!sharedTabGroups.containsKey(groupId)) {
          sharedTabGroups[groupId] = [];
        }
        sharedTabGroups[groupId]!.add(shop);
      } else {
        unsharedShops.add(shop);
      }
    }

    // 2. 各共有タブ内で作成日時順（古い順）にソート
    for (final groupShops in sharedTabGroups.values) {
      groupShops.sort((a, b) {
        final aDate = a.createdAt ?? DateTime(1970);
        final bDate = b.createdAt ?? DateTime(1970);
        return aDate.compareTo(bDate);
      });
    }

    // 3. 共有タブをグループID順（作成日時順）でソート
    final sortedGroups = sharedTabGroups.entries.toList()
      ..sort((a, b) {
        // 各グループの最初のタブの作成日時で比較
        final aFirstShop = a.value.first;
        final bFirstShop = b.value.first;
        final aDate = aFirstShop.createdAt ?? DateTime(1970);
        final bDate = bFirstShop.createdAt ?? DateTime(1970);
        return aDate.compareTo(bDate);
      });

    // 4. 共有していないタブも作成日時順（古い順）にソート
    unsharedShops.sort((a, b) {
      final aDate = a.createdAt ?? DateTime(1970);
      final bDate = b.createdAt ?? DateTime(1970);
      return aDate.compareTo(bDate);
    });

    // 5. 最終的な並び順を構築
    final List<Shop> sortedShops = [];

    // 共有タブを順番に追加
    for (final group in sortedGroups) {
      sortedShops.addAll(group.value);
    }

    // 共有していないタブを最後に追加
    sortedShops.addAll(unsharedShops);

    return sortedShops;
  }
}
