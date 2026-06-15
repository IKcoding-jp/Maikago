import 'package:flutter/material.dart';
import 'package:maikago/services/settings_theme.dart';

/// カメラ画面の下部コントロール（撮影ボタン、ズーム、説明テキスト）
class CameraBottomControls extends StatelessWidget {
  const CameraBottomControls({
    super.key,
    required this.isCapturing,
    required this.isCameraInitialized,
    required this.currentZoomLevel,
    required this.onCapture,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  /// 撮影中フラグ
  final bool isCapturing;

  /// カメラ初期化済みフラグ
  final bool isCameraInitialized;

  /// 現在のズームレベル
  final double currentZoomLevel;

  /// 撮影ボタン押下時のコールバック
  final VoidCallback onCapture;

  /// ズームインコールバック
  final VoidCallback onZoomIn;

  /// ズームアウトコールバック
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              AppColors.cameraBackground.withValues(alpha: 0.7),
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 撮影ボタン
            _buildCaptureButton(),
            const SizedBox(height: 16),

            // ズームコントロール
            if (isCameraInitialized) _buildZoomControls(context),
            const SizedBox(height: 16),

            // 説明テキスト
            _buildDescriptionText(context),
          ],
        ),
      ),
    );
  }

  /// 撮影ボタンの構築
  Widget _buildCaptureButton() {
    return GestureDetector(
      onTap: isCapturing ? null : onCapture,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isCapturing
              ? AppColors.cameraDisabled
              : AppColors.cameraForeground,
          border: Border.all(color: AppColors.cameraForeground, width: 4),
        ),
        child: isCapturing
            ? const CircularProgressIndicator(color: AppColors.cameraBackground)
            : const Icon(Icons.camera_alt,
                color: AppColors.cameraBackground, size: 40),
      ),
    );
  }

  /// 説明テキストの構築
  Widget _buildDescriptionText(BuildContext context) {
    return Text(
      '値札を正面から、できるだけ大きく\nピントを合わせて文字がくっきりした状態で\n撮影してください',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: AppColors.cameraForeground.withValues(alpha: 0.7),
        fontSize: Theme.of(context).textTheme.bodyMedium?.fontSize,
      ),
    );
  }

  /// ズームコントロールの構築
  Widget _buildZoomControls(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.cameraBackground.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onZoomOut,
            icon: const Icon(
              Icons.remove,
              color: AppColors.cameraForeground,
              size: 24,
            ),
            tooltip: 'ズームアウト',
            style: IconButton.styleFrom(
              backgroundColor: Colors.transparent,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: AppColors.cameraForeground.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${currentZoomLevel.toStringAsFixed(1)}x',
              style: TextStyle(
                color: AppColors.cameraForeground,
                fontSize: Theme.of(context).textTheme.bodySmall?.fontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            onPressed: onZoomIn,
            icon: const Icon(
              Icons.add,
              color: AppColors.cameraForeground,
              size: 24,
            ),
            tooltip: 'ズームイン',
            style: IconButton.styleFrom(
              backgroundColor: Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }
}
