import 'package:maikago/models/list.dart';
import 'package:maikago/models/sort_mode.dart';

/// MainScreen用の静的ユーティリティクラス
class MainScreenCalculations {
  MainScreenCalculations._();

  /// タブの高さを動的に計算
  static double calculateTabHeight(double fontSize) {
    const baseHeight = 24.0;
    final fontHeight = fontSize * 1.2;
    final totalHeight = baseHeight + fontHeight;
    return totalHeight.clamp(32.0, 60.0);
  }

  /// タブのパディングを動的に計算
  static double calculateTabPadding(double fontSize) {
    const basePadding = 6.0;
    final additionalPadding = (fontSize - 16.0) * 0.25;
    final totalPadding = basePadding + additionalPadding;
    return totalPadding.clamp(6.0, 16.0);
  }

  /// タブ内のテキストの最大行数を計算
  static int calculateMaxLines(double fontSize) {
    if (fontSize > 20) {
      return 1;
    } else if (fontSize > 18) {
      return 1;
    } else {
      return 2;
    }
  }

  /// ソートモードの比較関数
  static int Function(ListItem, ListItem) comparatorFor(SortMode mode) {
    switch (mode) {
      case SortMode.manual:
        return (a, b) {
          final orderCompare = a.sortOrder.compareTo(b.sortOrder);
          if (orderCompare != 0) return orderCompare;
          return a.id.compareTo(b.id);
        };
      case SortMode.priceAsc:
        return (a, b) => a.price.compareTo(b.price);
      case SortMode.priceDesc:
        return (a, b) => b.price.compareTo(a.price);
      case SortMode.qtyAsc:
        return (a, b) => a.quantity.compareTo(b.quantity);
      case SortMode.qtyDesc:
        return (a, b) => b.quantity.compareTo(a.quantity);
      case SortMode.dateNew:
        return (a, b) => (b.createdAt ?? DateTime.now()).compareTo(
              a.createdAt ?? DateTime.now(),
            );
      case SortMode.dateOld:
        return (a, b) => (a.createdAt ?? DateTime.now()).compareTo(
              b.createdAt ?? DateTime.now(),
            );
    }
  }
}
