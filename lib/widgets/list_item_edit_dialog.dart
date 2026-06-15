import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:maikago/models/list.dart';
import 'package:maikago/widgets/common_dialog.dart';

/// リスト編集ダイアログ
class ListItemEditDialog extends StatefulWidget {
  const ListItemEditDialog({
    super.key,
    required this.item,
    this.onUpdate,
    this.onDelete,
  });

  final ListItem item;
  final Function(ListItem)? onUpdate;
  final VoidCallback? onDelete;

  @override
  State<ListItemEditDialog> createState() => _ListItemEditDialogState();
}

class _ListItemEditDialogState extends State<ListItemEditDialog> {
  late TextEditingController _nameController;
  late TextEditingController _quantityController;
  late TextEditingController _priceController;
  late TextEditingController _discountController;

  late String _name;
  late int _quantity;
  late int _price;
  late double _discount;

  @override
  void initState() {
    super.initState();
    _name = widget.item.name;
    _quantity = widget.item.quantity;
    _price = widget.item.price;
    _discount = widget.item.discount;

    _nameController = TextEditingController(text: _name);
    _quantityController = TextEditingController(text: _quantity.toString());
    _priceController = TextEditingController(text: _price.toString());
    _discountController =
        TextEditingController(text: (_discount * 100).round().toString());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  void _updateQuantity(String value) {
    final newQuantity = int.tryParse(value) ?? 1;
    if (newQuantity >= 1 && newQuantity <= 999) {
      setState(() {
        _quantity = newQuantity;
      });
    }
  }

  void _updatePrice(String value) {
    final newPrice = int.tryParse(value) ?? 0;
    if (newPrice >= 0 && newPrice <= 999999) {
      setState(() {
        _price = newPrice;
      });
    }
  }

  void _updateDiscount(String value) {
    final newDiscount = int.tryParse(value) ?? 0;
    if (newDiscount >= 0 && newDiscount <= 100) {
      setState(() {
        _discount = newDiscount / 100;
      });
    }
  }

  void _updateName(String value) {
    setState(() {
      _name = value;
    });
  }

  void _showDeleteConfirmation(BuildContext context) {
    CommonDialog.show(
      context: context,
      builder: (BuildContext context) {
        return CommonDialog(
          title: '削除の確認',
          content: Text(
            '「$_name」を削除しますか？',
            overflow: TextOverflow.visible,
            maxLines: null,
            softWrap: true,
          ),
          actions: [
            CommonDialog.cancelButton(context),
            CommonDialog.destructiveButton(context, label: '削除', onPressed: () {
              context.pop(); // 削除確認ダイアログを閉じる
              context.pop(); // 編集ダイアログを閉じる
              widget.onDelete?.call();
            }),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return CommonDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: 'リスト編集',
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // アイテム名入力欄（titleから移動）
              TextField(
                controller: _nameController,
                maxLength: 100,
                buildCounter: (context,
                        {required currentLength,
                        required isFocused,
                        maxLength}) =>
                    null,
                decoration: InputDecoration(
                  labelText: 'アイテム名',
                  border: const OutlineInputBorder(),
                  hintText: 'アイテム名を入力してください',
                  fillColor: Theme.of(context).cardColor,
                  filled: true,
                ),
                onChanged: _updateName,
              ),
              const SizedBox(height: 16),
              // 個数入力欄
              TextField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                buildCounter: (context,
                        {required currentLength,
                        required isFocused,
                        maxLength}) =>
                    null,
                decoration: InputDecoration(
                  labelText: '個数',
                  border: const OutlineInputBorder(),
                  hintText: '1',
                  fillColor: Theme.of(context).cardColor,
                  filled: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  TextInputFormatter.withFunction((oldValue, newValue) {
                    if (newValue.text.isEmpty) return newValue;
                    if (newValue.text.startsWith('0') &&
                        newValue.text.length > 1) {
                      return TextEditingValue(
                        text: newValue.text.substring(1),
                        selection: TextSelection.collapsed(
                          offset: newValue.text.length - 1,
                        ),
                      );
                    }
                    return newValue;
                  }),
                ],
                onChanged: _updateQuantity,
              ),
              const SizedBox(height: 16),
              // 単価入力欄
              TextField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                maxLength: 8,
                buildCounter: (context,
                        {required currentLength,
                        required isFocused,
                        maxLength}) =>
                    null,
                decoration: InputDecoration(
                  labelText: '単価 (円)',
                  border: const OutlineInputBorder(),
                  hintText: '0',
                  prefixText: '¥',
                  fillColor: Theme.of(context).cardColor,
                  filled: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  TextInputFormatter.withFunction((oldValue, newValue) {
                    if (newValue.text.isEmpty) return newValue;
                    if (newValue.text.startsWith('0') &&
                        newValue.text.length > 1) {
                      return TextEditingValue(
                        text: newValue.text.substring(1),
                        selection: TextSelection.collapsed(
                          offset: newValue.text.length - 1,
                        ),
                      );
                    }
                    return newValue;
                  }),
                ],
                onChanged: _updatePrice,
              ),
              const SizedBox(height: 16),
              // 割引率入力欄
              TextField(
                controller: _discountController,
                keyboardType: TextInputType.number,
                maxLength: 3,
                buildCounter: (context,
                        {required currentLength,
                        required isFocused,
                        maxLength}) =>
                    null,
                decoration: InputDecoration(
                  labelText: '割引率 (%)',
                  border: const OutlineInputBorder(),
                  hintText: '0',
                  suffixText: '%',
                  fillColor: Theme.of(context).cardColor,
                  filled: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  TextInputFormatter.withFunction((oldValue, newValue) {
                    if (newValue.text.isEmpty) return newValue;
                    if (newValue.text.startsWith('0') &&
                        newValue.text.length > 1) {
                      return TextEditingValue(
                        text: newValue.text.substring(1),
                        selection: TextSelection.collapsed(
                          offset: newValue.text.length - 1,
                        ),
                      );
                    }
                    return newValue;
                  }),
                ],
                onChanged: _updateDiscount,
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
                  borderRadius: BorderRadius.circular(8),
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
                      '¥${(_price * _quantity * (1 - _discount)).round()}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
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
        CommonDialog.destructiveButton(context, label: '削除', onPressed: () {
          _showDeleteConfirmation(context);
        }),
        CommonDialog.primaryButton(context, label: '保存', onPressed: () {
          context.pop();
          // 更新されたアイテムを作成
          final updatedListItem = widget.item.copyWith(
            name: _name.trim(),
            quantity: _quantity,
            price: _price,
            discount: _discount,
          );
          // 更新処理を実行
          widget.onUpdate?.call(updatedListItem);
        }),
      ],
    );
  }
}
