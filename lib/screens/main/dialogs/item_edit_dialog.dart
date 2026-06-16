import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:maikago/providers/data_provider.dart';
import 'package:maikago/models/list.dart';
import 'package:maikago/models/shop.dart';
import 'package:maikago/services/settings_persistence.dart';
import 'package:maikago/utils/calculation_utils.dart';
import 'package:maikago/utils/input_formatters.dart';
import 'package:maikago/widgets/common_dialog.dart';
import 'package:go_router/go_router.dart';

/// アイテム追加/編集ダイアログ
class ItemEditDialog extends StatefulWidget {
  const ItemEditDialog({
    super.key,
    this.original,
    required this.shop,
    this.onItemSaved,
  });

  final ListItem? original;
  final Shop shop;
  final Future<void> Function()? onItemSaved;

  /// ダイアログを表示するヘルパーメソッド
  static Future<void> show(
    BuildContext context, {
    ListItem? original,
    required Shop shop,
    Future<void> Function()? onItemSaved,
  }) {
    return CommonDialog.show<void>(
      context: context,
      builder: (context) => ItemEditDialog(
        original: original,
        shop: shop,
        onItemSaved: onItemSaved,
      ),
    );
  }

  @override
  State<ItemEditDialog> createState() => _ItemEditDialogState();
}

class _ItemEditDialogState extends State<ItemEditDialog> {
  late final TextEditingController nameController;
  late final TextEditingController qtyController;
  late final TextEditingController priceController;
  late final TextEditingController discountController;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.original?.name ?? '');
    qtyController = TextEditingController(
      text: widget.original?.quantity.toString() ?? '1',
    );
    priceController = TextEditingController(
      text: widget.original?.price.toString() ?? '',
    );
    discountController = TextEditingController(
      text: ((widget.original?.discount ?? 0.0) * 100).round().toString(),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    qtyController.dispose();
    priceController.dispose();
    discountController.dispose();
    super.dispose();
  }

  int _calculateTotal() {
    final price = int.tryParse(priceController.text) ?? 0;
    final qty = int.tryParse(qtyController.text) ?? 1;
    final discountPercent = int.tryParse(discountController.text) ?? 0;
    return calcItemTotalRaw(
      price: price,
      quantity: qty,
      discount: discountPercent / 100.0,
    );
  }

  Future<void> _handleSave() async {
    final name = nameController.text.trim();
    final qty = int.tryParse(qtyController.text) ?? 1;
    final price = int.tryParse(priceController.text) ?? 0;
    final discount = (int.tryParse(discountController.text) ?? 0) / 100.0;
    if (name.isEmpty) return;

    final dataProvider = context.read<DataProvider>();

    try {
      final onItemSaved = widget.onItemSaved;
      final isAutoCompleteEnabled =
          await SettingsPersistence.loadAutoComplete();

      if (widget.original == null) {
        // 新規追加
        final shouldAutoComplete = isAutoCompleteEnabled && price > 0;
        final newItem = ListItem(
          id: '',
          name: name,
          quantity: qty,
          price: price,
          discount: discount,
          shopId: widget.shop.id,
          isChecked: shouldAutoComplete,
        );

        if (!mounted) return;
        context.pop(); // ダイアログを即座に閉じる
        await dataProvider.addItem(newItem);
      } else {
        // 編集
        final shouldAutoCompleteOnEdit =
            isAutoCompleteEnabled && (price > 0) && !widget.original!.isChecked;
        final updatedItem = widget.original!.copyWith(
          name: name,
          quantity: qty,
          price: price,
          discount: discount,
          isChecked:
              shouldAutoCompleteOnEdit ? true : widget.original!.isChecked,
        );

        if (!mounted) return;
        context.pop(); // ダイアログを即座に閉じる
        await dataProvider.updateItem(updatedItem);
      }

      await onItemSaved?.call();
    } catch (e) {
      // エラーは楽観的更新のロールバックで処理される
    }
  }

  @override
  Widget build(BuildContext context) {
    return CommonDialog(
      title: widget.original == null ? 'リストを追加' : 'リスト編集',
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // アイテム名入力欄
              TextField(
                controller: nameController,
                maxLength: 100,
                buildCounter: (context,
                        {required currentLength,
                        required isFocused,
                        maxLength}) =>
                    null,
                decoration: CommonDialog.textFieldDecoration(
                  context,
                  labelText: 'アイテム名',
                  hintText: 'アイテム名を入力してください',
                ),
              ),
              const SizedBox(height: 16),
              // 個数入力欄
              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                buildCounter: (context,
                        {required currentLength,
                        required isFocused,
                        maxLength}) =>
                    null,
                decoration: CommonDialog.textFieldDecoration(
                  context,
                  labelText: '個数',
                  hintText: '1',
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  noLeadingZeroFormatter(),
                ],
                onChanged: (value) => setState(() {}),
              ),
              const SizedBox(height: 16),
              // 単価入力欄
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                maxLength: 8,
                buildCounter: (context,
                        {required currentLength,
                        required isFocused,
                        maxLength}) =>
                    null,
                decoration: CommonDialog.textFieldDecoration(
                  context,
                  labelText: '単価 (円)',
                  hintText: '0',
                  prefixText: '¥',
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  noLeadingZeroFormatter(),
                ],
                onChanged: (value) => setState(() {}),
              ),
              const SizedBox(height: 16),
              // 割引率入力欄
              TextField(
                controller: discountController,
                keyboardType: TextInputType.number,
                maxLength: 3,
                buildCounter: (context,
                        {required currentLength,
                        required isFocused,
                        maxLength}) =>
                    null,
                decoration: CommonDialog.textFieldDecoration(
                  context,
                  labelText: '割引率 (%)',
                  hintText: '0',
                  suffixText: '%',
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  noLeadingZeroFormatter(),
                  // Issue #157: 割引率は100%まで（150%引き等を入力させない）
                  maxValueFormatter(100),
                ],
                onChanged: (value) => setState(() {}),
              ),
              const SizedBox(height: 16),
              // 合計金額表示
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '合計:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      '¥${_calculateTotal()}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize:
                            Theme.of(context).textTheme.bodyLarge?.fontSize,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        CommonDialog.cancelButton(context),
        CommonDialog.primaryButton(context,
            label: '保存', onPressed: _handleSave),
      ],
    );
  }
}
