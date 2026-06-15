import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:maikago/providers/data_provider.dart';
import 'package:maikago/utils/input_formatters.dart';
import 'package:maikago/widgets/common_dialog.dart';
import 'package:maikago/models/shop.dart';
import 'package:maikago/services/settings_persistence.dart';
import 'package:maikago/utils/snackbar_utils.dart';
import 'package:go_router/go_router.dart';

/// 予算変更ダイアログ
class BudgetDialog extends StatefulWidget {
  const BudgetDialog({super.key, required this.shop});

  final Shop shop;

  @override
  State<BudgetDialog> createState() => _BudgetDialogState();

  /// ダイアログを表示するヘルパーメソッド
  static Future<void> show(BuildContext context, Shop shop) {
    return CommonDialog.show<void>(
      context: context,
      builder: (context) => BudgetDialog(shop: shop),
    );
  }
}

class _BudgetDialogState extends State<BudgetDialog> {
  late TextEditingController controller;
  bool isLoading = true;
  late final String _initialBudgetText;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(
      text: widget.shop.budget?.toString() ?? '',
    );
    _initialBudgetText = controller.text;
    loadBudgetSettings();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> loadBudgetSettings() async {
    final currentBudget = await SettingsPersistence.getCurrentBudget(
      widget.shop.id,
    );

    setState(() {
      // ユーザー入力を上書きしない: 初期値のまま、または空のときだけ反映
      if (currentBudget != null) {
        final newText = currentBudget.toString();
        final isUserEdited =
            controller.text.isNotEmpty && controller.text != _initialBudgetText;
        if (!isUserEdited) {
          controller.text = newText;
        }
      }
      isLoading = false;
    });
  }

  Future<void> saveBudget() async {
    final budgetText = controller.text.trim();
    int? finalBudget;

    if (budgetText.isEmpty || budgetText == '0') {
      finalBudget = null;
    } else {
      final budget = int.tryParse(budgetText);
      if (budget == null) {
        showErrorSnackBar(context, '有効な数値を入力してください',
            duration: const Duration(seconds: 2));
        return;
      }
      finalBudget = budget;
    }

    final dataProvider = context.read<DataProvider>();

    try {
      final updatedShop = finalBudget == null
          ? widget.shop.copyWith(clearBudget: true)
          : widget.shop.copyWith(budget: finalBudget);
      final sharedTabGroupId = widget.shop.sharedTabGroupId;

      dataProvider.clearDisplayTotalCache();
      context.pop(); // ダイアログを即座に閉じる

      // Firestore書き込みはバックグラウンドで実行
      await SettingsPersistence.saveTabBudget(widget.shop.id, finalBudget);
      await dataProvider.updateShop(updatedShop);

      if (sharedTabGroupId != null) {
        await dataProvider.syncSharedTabBudget(sharedTabGroupId, finalBudget);
      }
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return CommonDialog.loading(context);
    }

    return CommonDialog(
      title: widget.shop.budget != null ? '予算を変更' : '予算を設定',
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.shop.budget != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    '現在の予算: ¥${widget.shop.budget}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                  ),
                ),
              TextField(
                controller: controller,
                maxLength: 8,
                buildCounter: (context,
                        {required currentLength,
                        required isFocused,
                        maxLength}) =>
                    null,
                decoration: CommonDialog.textFieldDecoration(
                  context,
                  labelText: '金額 (¥)',
                  helperText: '0を入力すると予算を未設定にできます',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  noLeadingZeroFormatter(allowSingleZero: true),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        CommonDialog.cancelButton(context),
        CommonDialog.primaryButton(context, label: '保存', onPressed: saveBudget),
      ],
    );
  }
}
