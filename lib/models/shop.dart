import 'package:flutter/foundation.dart';
import 'package:maikago/models/list.dart';
import 'package:maikago/models/sort_mode.dart';
import 'package:maikago/utils/json_parsers.dart';

class Shop {
  Shop({
    required this.id,
    required this.name,
    List<ListItem>? items,
    this.budget,
    this.createdAt,
    SortMode? incSortMode,
    SortMode? comSortMode,
    List<String>? sharedTabs,
    this.sharedTabGroupId,
    this.sharedTabGroupIcon,
  })  : items = List.unmodifiable(items ?? const []),
        incSortMode = incSortMode ?? SortMode.dateNew,
        comSortMode = comSortMode ?? SortMode.dateNew,
        sharedTabs = List.unmodifiable(sharedTabs ?? const []);

  factory Shop.fromJson(Map<String, dynamic> json) => Shop(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        items: _parseItems(json['items']),
        budget: parseNullableIntSafe(json['budget']),
        createdAt: parseDateTimeSafe(json['createdAt']),
        incSortMode: SortMode.values.firstWhere(
          (mode) => mode.name == json['incSortMode'],
          orElse: () => SortMode.dateNew,
        ),
        comSortMode: SortMode.values.firstWhere(
          (mode) => mode.name == json['comSortMode'],
          orElse: () => SortMode.dateNew,
        ),
        sharedTabs: (json['sharedTabs'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        // デュアルリード: 新フィールド優先、旧フィールドにフォールバック
        sharedTabGroupId:
            (json['sharedTabGroupId'] ?? json['sharedGroupId'])?.toString(),
        sharedTabGroupIcon:
            (json['sharedTabGroupIcon'] ?? json['sharedGroupIcon'])?.toString(),
      );

  factory Shop.fromMap(Map<String, dynamic> map) => Shop.fromJson(map);

  /// items 配列を防御的にパースする（Issue #164）。
  ///
  /// - List 以外（型不一致）なら空リストを返す
  /// - null・非 Map 要素は除去する
  /// - 個々のアイテム復元に失敗しても、その1件だけスキップし他は残す
  static List<ListItem> _parseItems(dynamic raw) {
    if (raw is! List) return const [];
    final items = <ListItem>[];
    for (final e in raw) {
      if (e is! Map) continue;
      try {
        items.add(ListItem.fromJson(Map<String, dynamic>.from(e)));
      } catch (error) {
        // 壊れた1件はスキップ。ユーザーデータは含めずカウントのみログ。
        if (kDebugMode) {
          debugPrint('Shop.fromJson: 壊れたアイテムをスキップしました ($error)');
        }
      }
    }
    return items;
  }

  final String id;
  final String name;
  final List<ListItem> items;
  final int? budget;
  final DateTime? createdAt;
  final SortMode incSortMode;
  final SortMode comSortMode;
  final List<String> sharedTabs;
  final String? sharedTabGroupId;
  final String? sharedTabGroupIcon;

  /// 不変更新用
  Shop copyWith({
    String? id,
    String? name,
    List<ListItem>? items,
    int? budget,
    DateTime? createdAt,
    bool clearBudget = false,
    SortMode? incSortMode,
    SortMode? comSortMode,
    List<String>? sharedTabs,
    String? sharedTabGroupId,
    bool clearSharedTabGroupId = false,
    String? sharedTabGroupIcon,
    bool clearSharedTabGroupIcon = false,
  }) {
    return Shop(
      id: id ?? this.id,
      name: name ?? this.name,
      items: items ?? List.from(this.items),
      budget: clearBudget ? null : (budget ?? this.budget),
      createdAt: createdAt ?? this.createdAt,
      incSortMode: incSortMode ?? this.incSortMode,
      comSortMode: comSortMode ?? this.comSortMode,
      sharedTabs: sharedTabs ?? List.from(this.sharedTabs),
      sharedTabGroupId: clearSharedTabGroupId
          ? null
          : (sharedTabGroupId ?? this.sharedTabGroupId),
      sharedTabGroupIcon: clearSharedTabGroupIcon
          ? null
          : (sharedTabGroupIcon ?? this.sharedTabGroupIcon),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'items': items.map((e) => e.toJson()).toList(),
        'budget': budget,
        'createdAt': createdAt?.toIso8601String(),
        'incSortMode': incSortMode.name,
        'comSortMode': comSortMode.name,
        'sharedTabs': sharedTabs.toList(),
        'sharedTabGroupId': sharedTabGroupId,
        'sharedTabGroupIcon': sharedTabGroupIcon,
      };

  Map<String, dynamic> toMap() => toJson();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Shop && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
