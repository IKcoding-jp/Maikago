import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:maikago/providers/data_provider.dart';
import 'package:maikago/widgets/common_dialog.dart';
import 'package:maikago/models/shop.dart';

/// タブ追加ダイアログ
class TabAddDialog extends StatefulWidget {
  const TabAddDialog({
    super.key,
    required this.nextShopId,
    this.onAdded,
  });

  final String nextShopId;
  final Future<void> Function(String newNextShopId)? onAdded;

  @override
  State<TabAddDialog> createState() => _TabAddDialogState();

  static Future<void> show(
    BuildContext context, {
    required String nextShopId,
    Future<void> Function(String newNextShopId)? onAdded,
  }) {
    return CommonDialog.show<void>(
      context: context,
      builder: (context) => TabAddDialog(
        nextShopId: nextShopId,
        onAdded: onAdded,
      ),
    );
  }
}

class _TabAddDialogState extends State<TabAddDialog> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _handleAdd() async {
    final name = controller.text.trim();
    if (name.isEmpty) return;

    final newShop = Shop(id: widget.nextShopId, name: name, items: []);
    final newNextShopId = (int.parse(widget.nextShopId) + 1).toString();
    final dataProvider = context.read<DataProvider>();
    final onAdded = widget.onAdded;

    context.pop(); // ダイアログを即座に閉じる

    try {
      await dataProvider.addShop(newShop);
      if (onAdded != null) {
        await onAdded(newNextShopId);
      }
    } catch (e) {
      // エラーは楽観的更新のロールバックで処理される
    }
  }

  @override
  Widget build(BuildContext context) {
    return CommonDialog(
      title: '新しいタブを追加',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: controller,
            maxLength: 50,
            buildCounter: (context,
                    {required currentLength, required isFocused, maxLength}) =>
                null,
            decoration:
                CommonDialog.textFieldDecoration(context, labelText: 'タブ名'),
          ),
        ],
      ),
      actions: [
        CommonDialog.cancelButton(context),
        CommonDialog.primaryButton(context, label: '追加', onPressed: _handleAdd),
      ],
    );
  }
}
