import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:maikago/services/vision_ocr_service.dart';
import 'package:maikago/utils/theme_utils.dart';

/// 画像解析の進行状況を表示するダイアログ
class ImageAnalysisProgressDialog extends StatefulWidget {
  const ImageAnalysisProgressDialog({
    super.key,
    this.onProgressUpdate,
  });

  final OcrProgressCallback? onProgressUpdate;

  @override
  State<ImageAnalysisProgressDialog> createState() =>
      _ImageAnalysisProgressDialogState();
}

class _ImageAnalysisProgressDialogState
    extends State<ImageAnalysisProgressDialog> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  String _currentMessage = '画像解析を開始中...';
  bool _isCompleted = false;
  bool _isFailed = false;

  final List<String> _defaultSteps = [
    '画像を最適化中...',
    'OCR解析を開始中...',
    '商品情報を抽出中...',
    'データを処理中...',
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.repeat();

    // デフォルトのステップアニメーションを開始
    _startDefaultStepAnimation();

    // 外部コールバックを設定
    if (widget.onProgressUpdate != null) {
      _setupProgressCallback();
    }
  }

  void _startDefaultStepAnimation() {
    int stepIndex = 0;
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted && !_isCompleted && !_isFailed) {
        setState(() {
          _currentMessage = _defaultSteps[stepIndex];
        });
        stepIndex = (stepIndex + 1) % _defaultSteps.length;
        _startDefaultStepAnimation();
      }
    });
  }

  void _setupProgressCallback() {
    // 外部から進行状況を更新するためのコールバック
    widget.onProgressUpdate
        ?.call(OcrProgressStep.initializing, _currentMessage);
  }

  void updateProgress(OcrProgressStep step, String message) {
    if (mounted) {
      setState(() {
        _currentMessage = message;
        if (step == OcrProgressStep.completed) {
          _isCompleted = true;
          _animationController.stop();
        } else if (step == OcrProgressStep.failed) {
          _isFailed = true;
          _animationController.stop();
        }
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Theme.of(context).dialogTheme.backgroundColor ??
          Theme.of(context).colorScheme.surface,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).dialogTheme.backgroundColor ??
              Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).cardShadowColor,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // アイコンとアニメーション
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _isFailed
                    ? Theme.of(context).colorScheme.error.withValues(alpha: 0.1)
                    : _isCompleted
                        ? Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.1)
                        : Theme.of(context).primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _animation.value * 2 * 3.14159,
                    child: Icon(
                      _isFailed
                          ? Icons.error
                          : _isCompleted
                              ? Icons.check_circle
                              : Icons.camera_alt,
                      size: 40,
                      color: _isFailed
                          ? Theme.of(context).colorScheme.error
                          : _isCompleted
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).primaryColor,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // タイトル
            Text(
              _isFailed
                  ? '解析エラー'
                  : _isCompleted
                      ? '解析完了'
                      : '画像解析中',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _isFailed
                        ? Theme.of(context).colorScheme.error
                        : _isCompleted
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).primaryColor,
                  ),
            ),
            const SizedBox(height: 16),

            // 進行状況テキスト
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _currentMessage,
                key: ValueKey(_currentMessage),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),

            // プログレスバー
            if (!_isCompleted && !_isFailed)
              LinearProgressIndicator(
                backgroundColor: Theme.of(context).dividerColor,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).primaryColor,
                ),
              ),

            // 完了/エラー時のボタン
            if (_isCompleted || _isFailed)
              ElevatedButton(
                onPressed: () => context.pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isFailed
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                child: Text(_isFailed ? '閉じる' : 'OK'),
              ),

            const SizedBox(height: 16),

            // ヒントテキスト
            if (!_isCompleted && !_isFailed)
              Text(
                'しばらくお待ちください...',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.color
                          ?.withValues(alpha: 0.7),
                    ),
              ),
          ],
        ),
      ),
    );
  }
}
