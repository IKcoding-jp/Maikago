import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:maikago/models/ocr_session_result.dart';
import 'package:maikago/providers/auth_provider.dart';
import 'package:maikago/screens/ocr_result_confirm_screen.dart';
import 'package:maikago/services/debug_service.dart';
import 'package:maikago/services/feature_access_control.dart';
import 'package:maikago/services/hybrid_ocr_service.dart';
import 'package:maikago/utils/dialog_utils.dart';
import 'package:maikago/utils/snackbar_utils.dart';
import 'package:maikago/widgets/common_dialog.dart';
import 'package:maikago/widgets/image_analysis_progress_dialog.dart';
import 'package:maikago/widgets/premium_upgrade_dialog.dart';
import 'package:maikago/widgets/recipe_import_bottom_sheet.dart';

/// OCR保存結果から「使用回数を消費すべきか」を判定する。
///
/// Issue #155: 確認画面のキャンセル（`null`）・保存失敗では消費しない。
/// 保存が成功した（＝ユーザーが値を得た）ときのみ `true` を返す。
bool shouldConsumeOcrUsage(SaveResult? saveResult) =>
    saveResult != null && saveResult.isSuccess;

/// ボトムサマリーのアクションボタン群
/// 予算変更・カメラ撮影・レシピ解析・リスト追加ボタンを含む
class BottomSummaryActions extends StatefulWidget {
  const BottomSummaryActions({
    super.key,
    required this.shopId,
    required this.onBudgetClick,
    required this.onFab,
    this.fabKey,
    this.budgetKey,
  });

  final String shopId;
  final VoidCallback onBudgetClick;
  final VoidCallback onFab;
  final GlobalKey? fabKey;
  final GlobalKey? budgetKey;

  @override
  State<BottomSummaryActions> createState() => _BottomSummaryActionsState();
}

class _BottomSummaryActionsState extends State<BottomSummaryActions> {
  // ハイブリッドOCRサービス
  final HybridOcrService _hybridOcrService = HybridOcrService();

  @override
  void initState() {
    super.initState();
    _initializeHybridOcr();
  }

  @override
  void dispose() {
    _hybridOcrService.dispose();
    super.dispose();
  }

  /// ハイブリッドOCRサービスの初期化
  Future<void> _initializeHybridOcr() async {
    try {
      await _hybridOcrService.initialize();
    } catch (e) {
      DebugService().logError('ハイブリッドOCR初期化エラー: $e');
    }
  }

  /// カメラ撮影ボタンが押された際の処理
  Future<void> _onImageAnalyzePressed() async {
    try {
      // OCR使用回数の制限チェック
      final featureControl = context.read<FeatureAccessControl>();
      if (!featureControl.canUseOcr()) {
        await PremiumUpgradeDialog.show(
          context,
          title: 'OCR回数制限',
          message:
              '今月の無料OCR（月${FeatureAccessControl.maxFreeOcrPerMonth}回）を使い切りました。\nプレミアムにアップグレードすると無制限に使えます。',
          onUpgrade: () => context.push('/subscription'),
        );
        return;
      }

      // 値札撮影カメラ画面を表示
      final result = await context.push<Map<String, dynamic>>(
        '/camera',
        extra: {
          'onImageCaptured': (File image) {
            context.pop({'type': 'image', 'data': image});
          },
        },
      );

      if (result == null) {
        return;
      }

      if (!mounted) return;

      // 値札撮影結果の処理
      if (result['type'] == 'image') {
        final imageFile = result['data'] as File;
        await _handleImageCaptured(imageFile);
      }
    } catch (e) {
      DebugService().logError('カメラ処理エラー: $e');
      if (mounted) {
        showErrorSnackBar(context, 'エラーが発生しました: $e');
      }
    }
  }

  /// レシピから追加ボタンが押された際の処理
  void _onRecipeImportPressed() {
    // ログインチェック
    final authProvider = context.read<AuthProvider>();
    if (!authProvider.isLoggedIn) {
      CommonDialog.show(
        context: context,
        builder: (context) => CommonDialog(
          title: 'ログインが必要です',
          content: const Text('レシピ解析機能を使うにはGoogleログインが必要です。'),
          actions: [
            CommonDialog.closeButton(context),
            CommonDialog.primaryButton(context, label: 'ログインする', onPressed: () {
              context.pop();
              context.push('/settings/account');
            }),
          ],
        ),
      );
      return;
    }

    // レシピ解析はプレミアム限定機能
    final featureControl = context.read<FeatureAccessControl>();
    if (!featureControl.canUseRecipeParser()) {
      PremiumUpgradeDialog.show(
        context,
        title: 'プレミアム機能',
        message: 'レシピ解析はプレミアム限定機能です。\nレシピテキストから買い物リストを自動作成できます。',
        onUpgrade: () => context.push('/subscription'),
      );
      return;
    }

    showConstrainedModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          Theme.of(context).colorScheme.surface.withValues(alpha: 0),
      builder: (context) => const RecipeImportBottomSheet(),
    );
  }

  /// 値札撮影結果の処理
  Future<void> _handleImageCaptured(File imageFile) async {
    try {
      // 改善されたローディングダイアログを表示
      unawaited(showConstrainedDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const ImageAnalysisProgressDialog(),
      ));

      // Cloud Functionsのみを使用した高速OCR解析
      final res = await _hybridOcrService.detectItemFromImageFast(
        imageFile,
      );

      if (!mounted) return;
      context.pop(); // ローディング閉じる

      if (res == null) {
        showErrorSnackBar(context, '読み取りに失敗しました');
        return;
      }

      // OCR結果からOcrSessionResultを作成
      final ocrResult = OcrSessionResult(
        items: [
          OcrSessionResultItem(
            id: const Uuid().v4(),
            name: res.name,
            price: res.price,
            quantity: 1,
          ),
        ],
        createdAt: DateTime.now(),
      );

      // OCR結果確認画面をダイアログで表示
      final saveResult = await OcrResultConfirmScreen.show(
        context,
        ocrResult: ocrResult,
        currentShopId: widget.shopId,
      );

      if (!mounted) return;

      // 保存成功時のみメッセージ表示とOCR使用回数の消費を行う。
      // Issue #155: キャンセル・保存失敗ではカウントを増やさない。
      if (shouldConsumeOcrUsage(saveResult)) {
        showSuccessSnackBar(context, saveResult!.message,
            duration: const Duration(seconds: 2));
        context.read<FeatureAccessControl>().incrementOcrUsage();
      }
    } catch (e) {
      DebugService().logError('値札画像処理エラー: $e');
      if (mounted) {
        showErrorSnackBar(context, '値札の読み取りに失敗しました: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 予算変更ボタン
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton(
              key: widget.budgetKey,
              onPressed: widget.onBudgetClick,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                elevation: 2,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                minimumSize: const Size(80, 40),
              ),
              child: Text(
                '予算変更',
                style: TextStyle(
                  fontSize: theme.textTheme.bodySmall?.fontSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // カメラで追加ボタン（Web では不可のため非表示）
        if (!kIsWeb) ...[
          Consumer<FeatureAccessControl>(
            builder: (context, featureControl, _) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  ElevatedButton(
                    onPressed: _onImageAnalyzePressed,
                    style: ElevatedButton.styleFrom(
                      shape: const CircleBorder(),
                      backgroundColor: colorScheme.primaryContainer,
                      foregroundColor: colorScheme.onPrimaryContainer,
                      elevation: 2,
                      padding: const EdgeInsets.all(12),
                      minimumSize: const Size(48, 48),
                    ),
                    child: const Icon(Icons.camera_alt_outlined, size: 24),
                  ),
                  if (!featureControl.isPremiumUnlocked)
                    Positioned(
                      top: -6,
                      right: -8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: featureControl.canUseOcr()
                              ? colorScheme.primary
                              : colorScheme.error,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${featureControl.ocrRemainingCount}',
                          style: TextStyle(
                            fontSize: 10,
                            color: colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 8),
        ],
        // レシピから追加ボタン（アイコンのみ）
        ElevatedButton(
          onPressed: _onRecipeImportPressed,
          style: ElevatedButton.styleFrom(
            shape: const CircleBorder(),
            backgroundColor: colorScheme.primaryContainer,
            foregroundColor: colorScheme.onPrimaryContainer,
            elevation: 2,
            padding: const EdgeInsets.all(12),
            minimumSize: const Size(48, 48),
          ),
          child: const Icon(Icons.receipt_long_outlined, size: 24),
        ),
        const SizedBox(width: 12),
        // リスト追加ボタン
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              key: widget.fabKey,
              onPressed: widget.onFab,
              icon: const Icon(Icons.add, size: 18),
              label: Text(
                'リスト追加',
                style: TextStyle(
                  fontSize: theme.textTheme.bodySmall?.fontSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                elevation: 2,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                minimumSize: const Size(80, 40),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
