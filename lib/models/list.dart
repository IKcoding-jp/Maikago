import 'package:maikago/utils/json_parsers.dart';

// リスト項目（数量・単価・割引・チェック状態）
class ListItem {
  // Issue #157: discount/price/quantity を範囲補正する唯一の入口。
  // fromJson・copyWith・直接生成のすべてがこのコンストラクタを通るため、
  // ここで正規化すれば全経路で不正値（負数・100%超割引）を防げる。
  ListItem({
    required this.id,
    required this.name,
    required int quantity,
    required int price,
    double discount = 0.0,
    this.isChecked = false,
    required this.shopId,
    this.createdAt,
    this.isReferencePrice = false,
    this.janCode,
    this.productUrl,
    this.imageUrl,
    this.storeName,
    this.timestamp,
    this.sortOrder = 0,
    this.isRecipeOrigin = false,
    this.recipeName,
  })  : quantity = quantity < 0 ? 0 : quantity,
        price = price < 0 ? 0 : price,
        discount = discount.clamp(0.0, 1.0);

  factory ListItem.fromJson(Map<String, dynamic> json) => ListItem(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        quantity: parseIntSafe(json['quantity']),
        price: parseIntSafe(json['price']),
        discount: parseDoubleSafe(json['discount']),
        isChecked: json['isChecked'] ?? false,
        shopId: json['shopId']?.toString() ?? '',
        createdAt: parseDateTimeSafe(json['createdAt']),
        isReferencePrice: json['isReferencePrice'] ?? false,
        janCode: json['janCode']?.toString(),
        productUrl: json['productUrl']?.toString(),
        imageUrl: json['imageUrl']?.toString(),
        storeName: json['storeName']?.toString(),
        timestamp: parseDateTimeSafe(json['timestamp']),
        sortOrder: parseIntSafe(json['sortOrder']),
        isRecipeOrigin: json['isRecipeOrigin'] ?? false,
        recipeName: json['recipeName']?.toString(),
      );

  factory ListItem.fromMap(Map<String, dynamic> map) => ListItem.fromJson(map);

  final String id;
  final String name;
  final int quantity;
  final int price;
  final double discount;
  final bool isChecked;

  /// どのショップに属するか
  final String shopId;
  final DateTime? createdAt;

  // バーコードスキャン関連のフィールド
  /// 参考価格フラグ
  final bool isReferencePrice;

  /// JANコード（バーコード）
  final String? janCode;

  /// 商品URL
  final String? productUrl;

  /// 商品画像URL
  final String? imageUrl;

  /// 店舗名
  final String? storeName;

  /// タイムスタンプ（追加日時）
  final DateTime? timestamp;

  /// 並べ替え順序（手動並び替え用）
  final int sortOrder;

  /// レシピ由来フラグ
  final bool isRecipeOrigin;

  /// レシピ名
  final String? recipeName;

  ListItem copyWith({
    String? id,
    String? name,
    int? quantity,
    int? price,
    double? discount,
    bool? isChecked,
    String? shopId,
    DateTime? createdAt,
    bool? isReferencePrice,
    String? janCode,
    String? productUrl,
    String? imageUrl,
    String? storeName,
    DateTime? timestamp,
    int? sortOrder,
    bool? isRecipeOrigin,
    String? recipeName,
  }) {
    return ListItem(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      discount: discount ?? this.discount,
      isChecked: isChecked ?? this.isChecked,
      shopId: shopId ?? this.shopId,
      createdAt: createdAt ?? this.createdAt,
      isReferencePrice: isReferencePrice ?? this.isReferencePrice,
      janCode: janCode ?? this.janCode,
      productUrl: productUrl ?? this.productUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      storeName: storeName ?? this.storeName,
      timestamp: timestamp ?? this.timestamp,
      sortOrder: sortOrder ?? this.sortOrder,
      isRecipeOrigin: isRecipeOrigin ?? this.isRecipeOrigin,
      recipeName: recipeName ?? this.recipeName,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'quantity': quantity,
        'price': price,
        'discount': discount,
        'isChecked': isChecked,
        'shopId': shopId,
        'createdAt': createdAt?.toIso8601String(),
        'isReferencePrice': isReferencePrice,
        'janCode': janCode,
        'productUrl': productUrl,
        'imageUrl': imageUrl,
        'storeName': storeName,
        'timestamp': timestamp?.toIso8601String(),
        'sortOrder': sortOrder,
        'isRecipeOrigin': isRecipeOrigin,
        'recipeName': recipeName,
      };

  Map<String, dynamic> toMap() => toJson();

  /// 税込み価格（10%）を取得。割引適用後に税を加算。
  int get priceWithTax {
    final discountedPrice = (price * (1 - discount)).round();
    return (discountedPrice * 1.1).round(); // 10%の消費税
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ListItem && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
