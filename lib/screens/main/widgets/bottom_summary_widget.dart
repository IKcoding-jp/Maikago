import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:maikago/providers/data_provider.dart';
import 'package:maikago/models/shop.dart';
import 'package:maikago/utils/calculation_utils.dart';
import 'package:maikago/services/settings_persistence.dart';
import 'package:maikago/services/debug_service.dart';
import 'package:maikago/screens/main/widgets/bottom_summary_actions.dart';
import 'package:maikago/screens/main/widgets/bottom_summary_details.dart';

/// ボトムサマリーウィジェット
/// 予算表示、合計金額表示、カメラ撮影、アイテム追加ボタンを含む
class BottomSummaryWidget extends StatefulWidget {
  const BottomSummaryWidget({
    super.key,
    required this.shop,
    required this.onBudgetClick,
    required this.onFab,
    this.fabKey,
    this.budgetKey,
  });

  final Shop shop;
  final VoidCallback onBudgetClick;
  final VoidCallback onFab;
  final GlobalKey? fabKey;
  final GlobalKey? budgetKey;

  @override
  State<BottomSummaryWidget> createState() => _BottomSummaryWidgetState();
}

class _BottomSummaryWidgetState extends State<BottomSummaryWidget> {
  String? _currentShopId;
  int? _cachedTotal;
  int? _cachedBudget;
  bool? _cachedSharedMode;
  int? _cachedCurrentTabTotal;
  bool _cacheInitialized = false;
  int? _lastItemsHash; // アイテムの変更検出用

  // DataProviderのリスナー
  DataProvider? _dataProvider;
  VoidCallback? _dataProviderListener;

  @override
  void initState() {
    super.initState();
    _currentShopId = widget.shop.id;
    _lastItemsHash = _calculateItemsHash();
    _refreshData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // DataProviderのリスナーを設定
    final newDataProvider = context.read<DataProvider>();
    if (_dataProvider != newDataProvider) {
      // 古いリスナーを削除
      if (_dataProvider != null && _dataProviderListener != null) {
        _dataProvider!.removeListener(_dataProviderListener!);
      }
      // 新しいリスナーを設定
      _dataProvider = newDataProvider;
      _dataProviderListener = _onDataProviderChanged;
      _dataProvider!.addListener(_dataProviderListener!);
    }
  }

  void _onDataProviderChanged() {
    // DataProviderの変更を検出してUIをリフレッシュ
    if (mounted) {
      _refreshData();
    }
  }

  @override
  void dispose() {
    // DataProviderのリスナーを削除
    if (_dataProvider != null && _dataProviderListener != null) {
      _dataProvider!.removeListener(_dataProviderListener!);
    }
    super.dispose();
  }

  /// アイテムリストのハッシュを計算（変更検出用）
  int _calculateItemsHash() {
    int hash = 0;
    for (final item in widget.shop.items) {
      hash ^= item.id.hashCode;
      hash ^= item.price.hashCode;
      hash ^= item.quantity.hashCode;
      hash ^= item.discount.hashCode;
      hash ^= item.isChecked.hashCode;
    }
    return hash;
  }

  @override
  void didUpdateWidget(BottomSummaryWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    final bool shopIdChanged = oldWidget.shop.id != widget.shop.id;
    final bool sharedTabGroupIdChanged =
        oldWidget.shop.sharedTabGroupId != widget.shop.sharedTabGroupId;
    final bool budgetChanged = oldWidget.shop.budget != widget.shop.budget;
    final int currentItemsHash = _calculateItemsHash();
    final bool itemsChanged = _lastItemsHash != currentItemsHash;

    if (shopIdChanged) {
      // タブ切り替え時: ちらつき防止のため、キャッシュをクリアせず新しいデータを取得
      _currentShopId = widget.shop.id;
      _lastItemsHash = currentItemsHash;
      _refreshData();
    } else if (sharedTabGroupIdChanged || itemsChanged || budgetChanged) {
      // 同じタブ内でのアイテム変更、同期タブ変更、または予算変更時
      _lastItemsHash = currentItemsHash;
      _refreshData();
    }
  }

  void _refreshData() {
    final String shopId = widget.shop.id;
    final String? sharedTabGroupId = widget.shop.sharedTabGroupId;
    _getAllSummaryData().then((data) {
      if (mounted) {
        if (shopId != widget.shop.id) return;
        if (sharedTabGroupId != widget.shop.sharedTabGroupId) return;

        setState(() {
          _cachedTotal = data['total'] as int;
          _cachedBudget = data['budget'] as int?;
          _cachedSharedMode = data['isSharedMode'] as bool;
          _cachedCurrentTabTotal = data['currentTabTotal'] as int?;
          _currentShopId = shopId;
          _cacheInitialized = true;
        });
      }
    });
  }

  // 現在のショップの即座の合計を計算
  int _calculateCurrentShopTotal() => calcShopTotal(widget.shop);

  // 全てのサマリーデータを一度に取得
  Future<Map<String, dynamic>> _getAllSummaryData() async {
    try {
      // 同期タブモードの場合
      if (widget.shop.sharedTabGroupId != null) {
        final dataProvider = context.read<DataProvider>();
        final sharedTotal =
            dataProvider.getSharedTabTotal(widget.shop.sharedTabGroupId!);
        final sharedBudget =
            dataProvider.getSharedTabBudget(widget.shop.sharedTabGroupId!);

        return {
          'total': sharedTotal,
          'currentTabTotal': _calculateCurrentShopTotal(),
          'budget': sharedBudget,
          'isSharedMode': true,
        };
      } else {
        // 個別モードの場合
        final total = _calculateCurrentShopTotal();
        final budget =
            await SettingsPersistence.loadTabBudget(widget.shop.id) ??
                widget.shop.budget;

        return {
          'total': total,
          'currentTabTotal': null,
          'budget': budget,
          'isSharedMode': false,
        };
      }
    } catch (e) {
      DebugService().logError('サマリーデータ取得エラー: $e');
      return {
        'total': _calculateCurrentShopTotal(),
        'currentTabTotal': null,
        'budget': widget.shop.budget,
        'isSharedMode': false,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    // 即座の計算値を使用（同期モード時は現在のタブのみ計算）
    final instantTotal = _calculateCurrentShopTotal();

    // キャッシュが初期化されていて、現在のショップに対応するキャッシュの場合はキャッシュを使用
    // タブ切り替え時はキャッシュ値を維持してちらつきを防止
    final bool useCache = _cacheInitialized && _currentShopId == widget.shop.id;

    final total = useCache ? (_cachedTotal ?? instantTotal) : instantTotal;
    final budget = useCache ? _cachedBudget : widget.shop.budget;
    final isSharedMode = useCache ? (_cachedSharedMode ?? false) : false;
    final currentTabTotal = useCache ? _cachedCurrentTabTotal : null;

    // 予算関連の計算
    final over = budget != null && total > budget;
    final remainingBudget = budget != null ? budget - total : null;
    final isNegative = remainingBudget != null && remainingBudget < 0;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor, width: 2),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        18,
        12,
        18,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // アクションボタン（予算変更、カメラ、レシピ、追加）
          BottomSummaryActions(
            shopId: widget.shop.id,
            onBudgetClick: widget.onBudgetClick,
            onFab: widget.onFab,
            fabKey: widget.fabKey,
            budgetKey: widget.budgetKey,
          ),
          const SizedBox(height: 10),
          // 予算・合計表示エリア
          BottomSummaryDetails(
            total: total,
            budget: budget,
            over: over,
            remainingBudget: remainingBudget,
            isNegative: isNegative,
            isSharedMode: isSharedMode,
            currentTabTotal: currentTabTotal,
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
