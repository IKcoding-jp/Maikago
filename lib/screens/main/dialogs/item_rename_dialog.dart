import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:maikago/providers/data_provider.dart';
import 'package:maikago/widgets/common_dialog.dart';
import 'package:maikago/utils/snackbar_utils.dart';
import 'package:maikago/models/list.dart';
import 'package:go_router/go_router.dart';

/// アイテム名前変更ダイアログ
class ItemRenameDialog extends StatefulWidget {
  const ItemRenameDialog({super.key, required this.item});

  final ListItem item;

  @override
  State<ItemRenameDialog> createState() => _ItemRenameDialogState();

  static Future<void> show(BuildContext context, ListItem item) {
    return CommonDialog.show(
      context: context,
      builder: (context) => ItemRenameDialog(item: item),
    );
  }
}

class _ItemRenameDialogState extends State<ItemRenameDialog> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.item.name);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final name = controller.text.trim();
    if (name.isEmpty) return;

    try {
      await context.read<DataProvider>().updateItem(
            widget.item.copyWith(name: name),
          );
      if (!mounted) return;
      context.pop();
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CommonDialog(
      title: '名前を変更',
      content: TextField(
        controller: controller,
        maxLength: 100,
        buildCounter: (context,
                {required currentLength, required isFocused, maxLength}) =>
            null,
        decoration: CommonDialog.textFieldDecoration(
          context,
          labelText: 'アイテム名',
          hintText: '新しい名前を入力してください',
        ),
        autofocus: true,
      ),
      actions: [
        CommonDialog.cancelButton(context),
        CommonDialog.primaryButton(context,
            label: '保存', onPressed: _handleSave),
      ],
    );
  }
}
