import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:maikago/services/recipe_parser_service.dart';

class RecipeImportBottomSheet extends StatefulWidget {
  const RecipeImportBottomSheet({super.key});

  @override
  State<RecipeImportBottomSheet> createState() =>
      _RecipeImportBottomSheetState();
}

class _RecipeImportBottomSheetState extends State<RecipeImportBottomSheet> {
  final TextEditingController _controller = TextEditingController();
  final RecipeParserService _recipeParserService = RecipeParserService();
  bool _isAnalyzing = false;
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onStartAnalysis() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() {
        _errorMessage = 'レシピテキストを貼り付けてください';
      });
      return;
    }

    if (text.length > 8000) {
      setState(() {
        _errorMessage = '長すぎるため分割してください';
      });
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
    });

    try {
      final (result, error) = await _recipeParserService.parseRecipe(text);
      if (!mounted) return;

      if (error != null) {
        setState(() {
          _isAnalyzing = false;
          _errorMessage = error.userMessage;
        });
      } else if (result != null) {
        // 確認画面へ遷移
        context.pop(); // ボトムシートを閉じる
        unawaited(context.push('/recipe-confirm', extra: {
          'initialIngredients': result.ingredients,
          'recipeTitle': result.title,
          'sourceText': text,
        }));
      }
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _errorMessage = 'エラーが発生しました: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'レシピを貼り付け',
                        style: TextStyle(
                            fontSize: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.fontSize,
                            fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => context.pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'レシピのテキストを貼り付けると、材料を買い物リストにまとめます。',
                    style: TextStyle(
                        fontSize:
                            Theme.of(context).textTheme.bodyMedium?.fontSize,
                        color: Theme.of(context).colorScheme.outline),
                  ),
                  Text(
                    '材料と作り方が混在していても解析します。',
                    style: TextStyle(
                        fontSize:
                            Theme.of(context).textTheme.bodySmall?.fontSize,
                        color: Theme.of(context).colorScheme.outline),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _controller,
                    maxLines: 6, // 8から少し減らしてスクロール時の安全マージンを確保
                    decoration: InputDecoration(
                      hintText: 'ここにレシピの文章を貼り付けてください',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      errorText: _errorMessage,
                    ),
                    onChanged: (val) {
                      if (_errorMessage != null) {
                        setState(() => _errorMessage = null);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '文字数: ${_controller.text.length} / 8,000（目安）',
                      style: TextStyle(
                        fontSize:
                            Theme.of(context).textTheme.bodySmall?.fontSize,
                        color: _controller.text.length > 8000
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isAnalyzing ? null : _onStartAnalysis,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                    child: _isAnalyzing
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          )
                        : Text('解析開始',
                            style: TextStyle(
                                fontSize: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.fontSize,
                                fontWeight: FontWeight.bold)),
                  ),
                  if (_isAnalyzing) ...[
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        '解析中です...\n材料を整理しています（約数秒）',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.fontSize,
                            color: Theme.of(context).colorScheme.outline),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
