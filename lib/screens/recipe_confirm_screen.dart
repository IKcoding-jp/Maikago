import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:maikago/models/list.dart';
import 'package:maikago/providers/data_provider.dart';
import 'package:maikago/services/recipe_parser_service.dart';
import 'package:uuid/uuid.dart';
import 'package:maikago/utils/snackbar_utils.dart';
import 'package:go_router/go_router.dart';
import 'package:maikago/widgets/common_dialog.dart';
import 'package:maikago/utils/theme_utils.dart';
import 'package:maikago/services/settings_theme.dart';

enum AddMode { append, integrate }

enum VolumeHandling { addUp, addSeparate }

class RecipeConfirmScreen extends StatefulWidget {
  const RecipeConfirmScreen({
    super.key,
    required this.initialIngredients,
    required this.recipeTitle,
    required this.sourceText,
  });

  final List<RecipeIngredient> initialIngredients;
  final String recipeTitle;
  final String sourceText;

  @override
  State<RecipeConfirmScreen> createState() => _RecipeConfirmScreenState();
}

class _RecipeConfirmScreenState extends State<RecipeConfirmScreen> {
  late List<RecipeIngredient> _ingredients;
  late TextEditingController _titleController;
  AddMode _addMode = AddMode.append;
  String? _selectedShopId;
  bool _isAdding = false;

  // 統合設定: 材料ごとの統合ON/OFFと分量処理
  final Map<int, bool> _integrationToggles = {};
  final Map<int, VolumeHandling> _volumeHandlings = {};
  final Map<int, ListItem?> _matchedItems = {};

  @override
  void initState() {
    super.initState();
    _ingredients = List.from(widget.initialIngredients);
    _titleController = TextEditingController(text: widget.recipeTitle);
    final dataProvider = Provider.of<DataProvider>(context, listen: false);
    if (dataProvider.shops.isNotEmpty) {
      _selectedShopId = dataProvider.shops.first.id;
    }

    // 初期設定
    for (int i = 0; i < _ingredients.length; i++) {
      _integrationToggles[i] = true;
      _volumeHandlings[i] = VolumeHandling.addUp;
      _findMatch(i);
    }
  }

  void _findMatch(int index) {
    final dataProvider = Provider.of<DataProvider>(context, listen: false);
    final ingredient = _ingredients[index];
    final targetName = ingredient.name.trim();

    // 材料名が空の場合はマッチングしない
    if (targetName.isEmpty) {
      _matchedItems[index] = null;
      return;
    }

    // 単純な名前一致で既存アイテムを探す
    // 1. 選択中のショップ内のみを対象とする
    // 2. 未購入（isChecked == false）のアイテムのみを対象とする
    final matched = dataProvider.items.firstWhere(
      (item) =>
          item.shopId == _selectedShopId &&
          !item.isChecked &&
          (item.name == targetName ||
              (ingredient.normalizedName.isNotEmpty &&
                  item.name == ingredient.normalizedName)),
      orElse: () =>
          ListItem(id: '', name: '', quantity: 0, price: 0, shopId: ''),
    );

    if (matched.id.isNotEmpty) {
      _matchedItems[index] = matched;
    } else {
      _matchedItems[index] = null;
    }
  }

  Future<void> _editIngredient(int index) async {
    final ingredient = _ingredients[index];
    final nameController = TextEditingController(text: ingredient.name);
    final qtyController =
        TextEditingController(text: ingredient.quantity ?? '');

    final result = await CommonDialog.show<Map<String, String>>(
      context: context,
      builder: (context) => CommonDialog(
        title: '材料の編集',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              maxLength: 100,
              buildCounter: (context,
                      {required currentLength,
                      required isFocused,
                      maxLength}) =>
                  null,
              decoration:
                  CommonDialog.textFieldDecoration(context, labelText: '材料名'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qtyController,
              maxLength: 50,
              buildCounter: (context,
                      {required currentLength,
                      required isFocused,
                      maxLength}) =>
                  null,
              decoration:
                  CommonDialog.textFieldDecoration(context, labelText: '分量'),
            ),
          ],
        ),
        actions: [
          CommonDialog.cancelButton(context),
          CommonDialog.primaryButton(context,
              label: '保存',
              onPressed: () => context.pop({
                    'name': nameController.text,
                    'quantity': qtyController.text,
                  })),
        ],
      ),
    );

    if (result != null) {
      setState(() {
        _ingredients[index].name = result['name']!;
        _ingredients[index].quantity =
            result['quantity']!.isEmpty ? null : result['quantity'];
        _findMatch(index);
      });
    }
  }

  void _deleteIngredient(int index) {
    setState(() {
      _ingredients.removeAt(index);
      // インデックスがずれるのでマップを再構築する必要があるが、
      // 簡単のため、このデモではインデックス管理を工夫するか、リスト全体を再構築する
      final newToggles = <int, bool>{};
      final newVolume = <int, VolumeHandling>{};

      for (int i = 0; i < _ingredients.length; i++) {
        // 削除された分を飛ばして再割り当て（不完全だが、とりあえずの実装）
        // 本来はIDベースで管理すべき
        newToggles[i] = true;
        newVolume[i] = VolumeHandling.addUp;
      }
      _integrationToggles.clear();
      _integrationToggles.addAll(newToggles);
      _volumeHandlings.clear();
      _volumeHandlings.addAll(newVolume);

      // 再検索
      for (int i = 0; i < _ingredients.length; i++) {
        _findMatch(i);
      }
    });
  }

  Future<void> _onAdd() async {
    if (_isAdding) return;
    setState(() => _isAdding = true);

    final dataProvider = Provider.of<DataProvider>(context, listen: false);
    final shopId = _selectedShopId ?? '0';
    final recipeTitle = _titleController.text.trim();

    final futures = <Future<void>>[];

    for (int i = 0; i < _ingredients.length; i++) {
      final ingredient = _ingredients[i];

      final bool shouldIntegrate = _addMode == AddMode.integrate &&
          _integrationToggles[i] == true &&
          _matchedItems[i] != null;

      if (shouldIntegrate && _volumeHandlings[i] == VolumeHandling.addUp) {
        final existing = _matchedItems[i]!;
        futures.add(dataProvider.updateItem(existing.copyWith(
          quantity: existing.quantity + 1,
          isRecipeOrigin: true,
          recipeName: recipeTitle,
        )));
      } else {
        final displayName = ingredient.quantity != null
            ? '${ingredient.name} (${ingredient.quantity})'
            : ingredient.name;

        final newItem = ListItem(
          id: const Uuid().v4(),
          name: displayName,
          quantity: 1,
          price: 0,
          shopId: shopId,
          isRecipeOrigin: true,
          recipeName: recipeTitle,
          createdAt: DateTime.now(),
        );
        futures.add(dataProvider.addItem(newItem));
      }
    }

    if (!mounted) return;
    showSuccessSnackBar(context, '買い物リストに追加しました',
        duration: const Duration(seconds: 2));
    context.pop(); // 画面を即座に閉じる
  }

  @override
  Widget build(BuildContext context) {
    final dataProvider = context.read<DataProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('材料の確認'),
      ),
      body: Column(
        children: [
          _buildHeader(dataProvider),
          const Divider(),
          Expanded(
            child: ListView.separated(
              itemCount: _ingredients.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) => _buildIngredientTile(index),
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader(DataProvider dataProvider) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              const Text('レシピ名: '),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _titleController,
                  maxLength: 100,
                  buildCounter: (context,
                          {required currentLength,
                          required isFocused,
                          maxLength}) =>
                      null,
                  decoration: CommonDialog.textFieldDecoration(
                    context,
                    hintText: 'レシピの名称（例: 肉じゃが）',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('追加先: '),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<String>(
                  value: _selectedShopId,
                  isExpanded: true,
                  items: dataProvider.shops.map((shop) {
                    return DropdownMenuItem(
                      value: shop.id,
                      child: Text(shop.name),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedShopId = val;
                      // ショップを選択し直した場合は、各材料の既存一致を再検索する
                      for (int i = 0; i < _ingredients.length; i++) {
                        _findMatch(i);
                      }
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('方式 : '),
              _modeChip('追記', AddMode.append),
              const SizedBox(width: 8),
              _modeChip('統合', AddMode.integrate),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '※レシピ由来タグは追加後に表示されます',
            style: TextStyle(
                fontSize: Theme.of(context).textTheme.bodySmall?.fontSize,
                color: Theme.of(context).subtextColor),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientTile(int index) {
    final ingredient = _ingredients[index];
    final matched = _matchedItems[index];
    final isIntegrateMode = _addMode == AddMode.integrate;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ingredient.name,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize:
                              Theme.of(context).textTheme.bodyLarge?.fontSize),
                    ),
                    if (ingredient.quantity != null)
                      Text(ingredient.quantity!,
                          style:
                              TextStyle(color: Theme.of(context).subtextColor))
                    else
                      Text('分量が曖昧なため省略しました',
                          style: TextStyle(
                              fontSize: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.fontSize,
                              color: AppColors.warning)),
                  ],
                ),
              ),
              TextButton(
                  onPressed: () => _editIngredient(index),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                  ),
                  child: const Text('編集')),
              IconButton(
                  onPressed: () => _deleteIngredient(index),
                  icon: Icon(Icons.delete_outline,
                      color: Theme.of(context).colorScheme.error)),
            ],
          ),
          if (isIntegrateMode) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Text('統合: ', style: TextStyle(fontSize: 13)),
                Switch(
                  value: _integrationToggles[index] ?? false,
                  onChanged: matched == null
                      ? null
                      : (val) =>
                          setState(() => _integrationToggles[index] = val),
                ),
                if (matched != null &&
                    (_integrationToggles[index] ?? false)) ...[
                  const SizedBox(width: 8),
                  const Text('分量: ', style: TextStyle(fontSize: 13)),
                  DropdownButton<VolumeHandling>(
                    value: _volumeHandlings[index],
                    items: const [
                      DropdownMenuItem(
                          value: VolumeHandling.addUp, child: Text('合算')),
                      DropdownMenuItem(
                          value: VolumeHandling.addSeparate,
                          child: Text('別追加')),
                    ],
                    onChanged: (val) =>
                        setState(() => _volumeHandlings[index] = val!),
                  ),
                ],
              ],
            ),
            if (matched != null && (_integrationToggles[index] ?? false))
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '一致候補: 「${matched.name} ${matched.quantity}個（既存）」',
                  style: TextStyle(
                      fontSize: Theme.of(context).textTheme.bodySmall?.fontSize,
                      color: Theme.of(context).colorScheme.primary),
                ),
              )
            else if (isIntegrateMode && matched == null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('一致するアイテムが見つかりません',
                    style: TextStyle(
                        fontSize: 11, color: Theme.of(context).subtextColor)),
              ),
          ],
        ],
      ),
    );
  }

  Widget _modeChip(String label, AddMode mode) {
    final selected = _addMode == mode;
    final colorScheme = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: colorScheme.primary,
      backgroundColor: colorScheme.surface,
      side: BorderSide(
        color: selected ? colorScheme.primary : colorScheme.outline,
      ),
      labelStyle: TextStyle(
        color: selected ? colorScheme.onPrimary : colorScheme.onSurface,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
      showCheckmark: false,
      onSelected: (_) => setState(() => _addMode = mode),
    );
  }

  Widget _buildFooter() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
              color: Theme.of(context).cardShadowColor,
              blurRadius: 10,
              offset: const Offset(0, -5))
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                    side: BorderSide(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Text('戻る'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isAdding ? null : _onAdd,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                  child: const Text('追加する',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
