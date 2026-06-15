import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:go_router/go_router.dart';

import 'package:maikago/models/ocr_session_result.dart';
import 'package:maikago/models/list.dart';
import 'package:maikago/models/shop.dart';
import 'package:maikago/providers/data_provider.dart';
import 'package:maikago/utils/dialog_utils.dart';
import 'package:maikago/utils/snackbar_utils.dart';

import 'package:maikago/screens/ocr_result_item_widgets.dart';
import 'package:maikago/screens/ocr_result_dialogs.dart';

/// OCR結果確認・編集画面
class OcrResultConfirmScreen extends StatefulWidget {
  const OcrResultConfirmScreen({
    super.key,
    required this.ocrResult,
    required this.currentShopId,
  });

  final OcrSessionResult ocrResult;
  final String currentShopId;

  /// ダイアログとして表示するヘルパーメソッド
  static Future<SaveResult?> show(
    BuildContext context, {
    required OcrSessionResult ocrResult,
    required String currentShopId,
  }) {
    return showConstrainedDialog<SaveResult>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 600,
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: OcrResultConfirmScreen(
            ocrResult: ocrResult,
            currentShopId: currentShopId,
          ),
        ),
      ),
    );
  }

  @override
  State<OcrResultConfirmScreen> createState() => _OcrResultConfirmScreenState();
}

class _OcrResultConfirmScreenState extends State<OcrResultConfirmScreen> {
  late List<OcrSessionResultItem> _items;
  bool _isProcessing = false;

  /// インデックスごとのマッチング情報: OCRアイテムIndex -> 既存アイテム
  final Map<int, ListItem?> _matchedItems = {};

  /// ユーザーが上書きを選択したインデックスのセット
  final Set<int> _itemsToOverwrite = {};

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.ocrResult.items);

    // 初期状態で現在のショップとのマッチングを実行
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runInitialMatching();
    });
  }

  // ---------------------------------------------------------------------------
  // マッチングロジック
  // ---------------------------------------------------------------------------

  /// 初期マッチング実行
  void _runInitialMatching() {
    final dataProvider = context.read<DataProvider>();
    final currentShop = _findCurrentShop(dataProvider);

    if (currentShop.id.isNotEmpty) {
      _matchItems(currentShop.items);
    }
  }

  /// 商品マッチングロジック
  void _matchItems(List<ListItem> existingItems) {
    setState(() {
      _matchedItems.clear();
      _itemsToOverwrite.clear();

      for (int i = 0; i < _items.length; i++) {
        final ocrItem = _items[i];
        if (ocrItem.name.isEmpty) continue;

        final match = existingItems.cast<ListItem?>().firstWhere(
          (e) {
            final existingName = _normalize(e!.name);
            final ocrName = _normalize(ocrItem.name);
            return existingName == ocrName ||
                existingName.contains(ocrName) ||
                ocrName.contains(existingName);
          },
          orElse: () => null,
        );

        if (match != null) {
          _matchedItems[i] = match;
          _itemsToOverwrite.add(i);
        }
      }
    });
  }

  /// 簡易的な文字列正規化（マッチング精度向上用）
  String _normalize(String text) {
    return text.replaceAll(RegExp(r'\s+'), '').toLowerCase();
  }

  // ---------------------------------------------------------------------------
  // アイテム操作
  // ---------------------------------------------------------------------------

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
      _matchedItems.remove(index);
      _itemsToOverwrite.remove(index);
      _runInitialMatching();
    });
  }

  void _updateItem(int index, OcrSessionResultItem updatedItem) {
    setState(() {
      _items[index] = updatedItem;
    });
  }

  void _unlinkMatch(int index) {
    setState(() {
      _matchedItems.remove(index);
      _itemsToOverwrite.remove(index);
    });
  }

  void _setOverwrite(int index, bool value) {
    setState(() {
      if (value) {
        _itemsToOverwrite.add(index);
      } else {
        _itemsToOverwrite.remove(index);
      }
    });
  }

  /// 既存商品を選択するダイアログを表示
  Future<void> _handleSelectExistingItem(int index) async {
    final dataProvider = context.read<DataProvider>();
    final currentShop = _findCurrentShop(dataProvider);

    if (currentShop.id.isEmpty) return;

    final selected = await showSelectExistingItemDialog(
      context,
      currentShop: currentShop,
    );

    if (selected != null) {
      setState(() {
        _matchedItems[index] = selected;
        _itemsToOverwrite.add(index);
      });
    }
  }

  // ---------------------------------------------------------------------------
  // 保存
  // ---------------------------------------------------------------------------

  Future<void> _handleSave() async {
    if (_isProcessing) return;
    if (_items.isEmpty) {
      showInfoSnackBar(context, '商品を1つ以上追加してください');
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      await _saveToCurrentShop();
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  /// 現在のショップにマージ保存
  Future<void> _saveToCurrentShop() async {
    final dataProvider = context.read<DataProvider>();
    const uuid = Uuid();

    final currentShop = _findCurrentShop(dataProvider);
    if (currentShop.id.isEmpty) {
      if (mounted) {
        showInfoSnackBar(context, '保存先リストが見つかりません');
      }
      return;
    }

    int updatedCount = 0;
    int addedCount = 0;

    for (int i = 0; i < _items.length; i++) {
      final item = _items[i];
      final matched = _matchedItems[i];
      final doOverwrite = _itemsToOverwrite.contains(i);

      if (matched != null && doOverwrite) {
        final updatedItem = matched.copyWith(
          price: item.price,
          quantity: item.quantity,
          timestamp: DateTime.now(),
        );
        await dataProvider.updateItem(updatedItem);
        updatedCount++;
      } else {
        final listItem = ListItem(
          id: uuid.v4(),
          name: item.name,
          quantity: item.quantity,
          price: item.price,
          shopId: widget.currentShopId,
          createdAt: DateTime.now(),
          timestamp: DateTime.now(),
        );
        await dataProvider.addItem(listItem);
        addedCount++;
      }
    }

    if (mounted) {
      context.pop(
        SaveResult.success(
          message: '$updatedCount件更新、$addedCount件追加しました',
          targetShopId: widget.currentShopId,
          isUpdateMode: true,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // ヘルパー
  // ---------------------------------------------------------------------------

  /// 現在のショップを取得
  Shop _findCurrentShop(DataProvider dataProvider) {
    return dataProvider.shops.firstWhere(
      (s) => s.id == widget.currentShopId,
      orElse: () => Shop(id: '', name: ''),
    );
  }

  /// 合計金額の差分を計算
  _TotalDiff _calculateTotalDiff(DataProvider dataProvider) {
    final currentShop = dataProvider.shops.firstWhere(
      (s) => s.id == widget.currentShopId,
      orElse: () => Shop(id: '', name: '', items: []),
    );

    int currentTotal = 0;
    for (final item in currentShop.items) {
      if (!item.isChecked) {
        currentTotal += item.price * item.quantity;
      }
    }

    int diff = 0;
    for (int i = 0; i < _items.length; i++) {
      final newItem = _items[i];
      final matchedItem = _matchedItems[i];
      final isOverwrite = _itemsToOverwrite.contains(i);

      if (matchedItem != null && isOverwrite) {
        diff += (newItem.price * newItem.quantity) -
            (matchedItem.price * matchedItem.quantity);
      } else {
        diff += newItem.price * newItem.quantity;
      }
    }

    return _TotalDiff(currentTotal: currentTotal, diff: diff);
  }

  // ---------------------------------------------------------------------------
  // build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dataProvider = context.read<DataProvider>();
    final totalDiff = _calculateTotalDiff(dataProvider);

    return Material(
      color: theme.colorScheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // カスタムヘッダー
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '読み取り結果の確認',
                  style: theme.textTheme.titleLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => context.pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // 商品リスト
          Flexible(
            child: _items.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: OcrResultEmptyState(),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    shrinkWrap: true,
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      return OcrResultItemCard(
                        item: _items[index],
                        index: index,
                        matchedItem: _matchedItems[index],
                        isOverwrite: _itemsToOverwrite.contains(index),
                        onItemChanged: (updated) => _updateItem(index, updated),
                        onRemove: () => _removeItem(index),
                        onOverwriteChanged: (val) => _setOverwrite(index, val),
                        onUnlinkMatch: () => _unlinkMatch(index),
                        onLinkExistingItem: () =>
                            _handleSelectExistingItem(index),
                      );
                    },
                  ),
          ),
          // 合計金額
          OcrResultTotalSummary(
            currentTotal: totalDiff.currentTotal,
            diff: totalDiff.diff,
          ),
          // 保存ボタン
          OcrResultSaveButton(
            isProcessing: _isProcessing,
            onSave: _handleSave,
          ),
        ],
      ),
    );
  }
}

/// 合計金額の差分情報
class _TotalDiff {
  const _TotalDiff({required this.currentTotal, required this.diff});
  final int currentTotal;
  final int diff;
}
