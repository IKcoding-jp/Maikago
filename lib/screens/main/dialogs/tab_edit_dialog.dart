import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:maikago/providers/data_provider.dart';
import 'package:maikago/widgets/common_dialog.dart';
import 'package:maikago/models/shop.dart';
import 'package:go_router/go_router.dart';

/// タブ編集ダイアログ
class TabEditDialog extends StatefulWidget {
  const TabEditDialog({
    super.key,
    required this.tabIndex,
    required this.shops,
    this.customTheme,
  });

  final int tabIndex;
  final List<Shop> shops;
  final ThemeData? customTheme;

  /// ダイアログを表示するヘルパーメソッド
  static Future<void> show(
    BuildContext context, {
    required int tabIndex,
    required List<Shop> shops,
    ThemeData? customTheme,
  }) {
    return CommonDialog.show(
      context: context,
      builder: (context) => TabEditDialog(
        tabIndex: tabIndex,
        shops: shops,
        customTheme: customTheme,
      ),
    );
  }

  @override
  State<TabEditDialog> createState() => _TabEditDialogState();
}

class _TabEditDialogState extends State<TabEditDialog> {
  late final TextEditingController controller;
  late Shop currentShop;
  late List<Shop> otherShops;
  late Set<String> selectedTabIds;
  String? selectedIconName;

  @override
  void initState() {
    super.initState();
    currentShop = widget.shops[widget.tabIndex];
    controller = TextEditingController(text: currentShop.name);
    otherShops =
        widget.shops.where((shop) => shop.id != currentShop.id).toList();
    selectedTabIds = Set<String>.from(currentShop.sharedTabs);
    selectedIconName = currentShop.sharedTabGroupIcon;
    _buildShareOptions();
  }

  /// 同期選択肢を構築（同期タブは1つの単位として表示）
  late List<_ShareOption> _shareOptions;

  void _buildShareOptions() {
    final currentGroupId = currentShop.sharedTabGroupId;
    final Map<String, List<Shop>> externalGroups = {};
    final List<Shop> individualShops = [];

    for (final shop in otherShops) {
      if (shop.sharedTabGroupId != null &&
          shop.sharedTabGroupId != currentGroupId) {
        // 自分のグループ以外の同期タブ → グループ単位で表示
        externalGroups.putIfAbsent(shop.sharedTabGroupId!, () => []).add(shop);
      } else {
        // 未同期タブ or 自分のグループのメンバー → 個別表示
        individualShops.add(shop);
      }
    }

    _shareOptions = [];

    // 外部グループを1つの選択肢として追加
    for (final entry in externalGroups.entries) {
      final groupShops = entry.value;
      final memberIds = groupShops.map((s) => s.id).toSet();
      final label = groupShops.map((s) => s.name).join(' + ');
      final icon = groupShops.first.sharedTabGroupIcon;
      _shareOptions.add(_ShareOption(
        label: label,
        memberIds: memberIds,
        isGroup: true,
        groupIcon: icon,
      ));
    }

    // 個別タブを追加
    for (final shop in individualShops) {
      _shareOptions.add(_ShareOption(
        label: shop.name,
        memberIds: {shop.id},
        isGroup: false,
      ));
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _handleDelete() async {
    final shopToDelete = widget.shops[widget.tabIndex];
    final dataProvider = context.read<DataProvider>();
    context.pop(); // ダイアログを即座に閉じる
    await dataProvider.deleteShop(shopToDelete.id);
  }

  Future<void> _handleSave() async {
    final name = controller.text.trim();
    if (name.isEmpty) return;

    final dataProvider = context.read<DataProvider>();
    context.pop(); // ダイアログを即座に閉じる

    // Firestore書き込みはバックグラウンドで実行（楽観的更新済み）
    if (selectedTabIds.isNotEmpty) {
      await dataProvider.updateSharedTab(
        currentShop.id,
        selectedTabIds.toList(),
        name: name,
        sharedTabGroupIcon: selectedIconName,
      );
    } else if (currentShop.sharedTabGroupId != null ||
        currentShop.sharedTabs.isNotEmpty) {
      await dataProvider.removeFromSharedTab(
        currentShop.id,
        originalSharedTabGroupId: currentShop.sharedTabGroupId,
        name: name,
      );
    } else {
      final updatedShop = currentShop.copyWith(name: name);
      await dataProvider.updateShop(updatedShop);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.customTheme ?? Theme.of(context);

    return Theme(
      data: theme,
      child: CommonDialog(
        title: 'タブ編集',
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                maxLength: 50,
                buildCounter: (context,
                        {required currentLength,
                        required isFocused,
                        maxLength}) =>
                    null,
                decoration: CommonDialog.textFieldDecoration(
                  context,
                  labelText: 'タブ名',
                ),
              ),
              const SizedBox(height: 16),
              if (otherShops.isNotEmpty) ...[
                Text(
                  '同期するタブを選択',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ..._shareOptions.map((option) {
                  final isChecked =
                      option.memberIds.every(selectedTabIds.contains);
                  return CheckboxListTile(
                    title: Text(option.label),
                    subtitle: option.isGroup
                        ? Text(
                            '同期タブ',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          )
                        : null,
                    value: isChecked,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          selectedTabIds.addAll(option.memberIds);
                        } else {
                          selectedTabIds.removeAll(option.memberIds);
                        }
                      });
                    },
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  );
                }),
                if (selectedTabIds.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '同期したいタブを選択すると同期が有効になります。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.hintColor,
                      ),
                    ),
                  ),
              ],
              if (otherShops.isEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  '同期できる他のタブがありません。',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (widget.shops.length > 1)
            CommonDialog.destructiveButton(context, onPressed: _handleDelete),
          CommonDialog.cancelButton(context),
          CommonDialog.primaryButton(context,
              label: '保存', onPressed: _handleSave),
        ],
      ),
    );
  }
}

/// 同期選択肢（個別タブまたはグループ単位）
class _ShareOption {
  const _ShareOption({
    required this.label,
    required this.memberIds,
    required this.isGroup,
    this.groupIcon,
  });

  final String label;
  final Set<String> memberIds;
  final bool isGroup;
  final String? groupIcon;
}
