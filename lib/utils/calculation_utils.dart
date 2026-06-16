// 金額計算の唯一の正となるユーティリティ（Issue #156）。
//
// 丸めは「アイテム単位（数量を掛けてから）で1回」に統一する。
// 合計・割引の計算式を screens / widgets に直書きせず、必ずこの関数群を使うこと。
// 依存方向は utils → models の一方向のみ（models からは import しない）。
import 'package:maikago/models/list.dart';
import 'package:maikago/models/shop.dart';

/// 素の値から1アイテムの小計を計算する（数量込み・割引後）。
///
/// 丸めは数量を掛けた後に1回だけ行う（`(price × quantity × (1 - discount)).round()`）。
/// 単価で丸めてから数量を掛けると、割引で端数が出たとき合計が個数分ズレるため禁止。
/// discount は 0.0〜1.0 にクランプして不正値（負数・100%超割引）を防ぐ。
int calcItemTotalRaw({
  required int price,
  required int quantity,
  required double discount,
}) {
  final d = discount.clamp(0.0, 1.0);
  return (price * quantity * (1 - d)).round();
}

/// 1アイテムの小計（数量込み・割引後）。
int calcItemTotal(ListItem item) => calcItemTotalRaw(
      price: item.price,
      quantity: item.quantity,
      discount: item.discount,
    );

/// ショップ内アイテムの合計。既定はチェック済みのみ集計する。
///
/// 全件を集計する場合は [checkedOnly] を false にする。
int calcShopTotal(Shop shop, {bool checkedOnly = true}) {
  final items =
      checkedOnly ? shop.items.where((item) => item.isChecked) : shop.items;
  return items.fold<int>(0, (sum, item) => sum + calcItemTotal(item));
}

/// 1個あたりの割引後単価（数量を掛けない表示用）。
///
/// 単価そのものの表示に使う。合計には使わないこと（合計は [calcItemTotal] / [calcShopTotal]）。
int calcDiscountedUnitPrice(int price, double discount) {
  final d = discount.clamp(0.0, 1.0);
  return (price * (1 - d)).round();
}
