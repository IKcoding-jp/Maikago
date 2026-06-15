import 'package:flutter/material.dart';
import 'package:maikago/services/settings_theme.dart';

/// カメラ画面の上部バー（閉じるボタン、タイトル、ギャラリーボタン、ヘルプボタン）
class CameraTopBar extends StatelessWidget {
  const CameraTopBar({
    super.key,
    required this.onClose,
    required this.onHelp,
    this.onPickFromGallery,
  });

  /// 閉じるボタン押下時のコールバック
  final VoidCallback onClose;

  /// ヘルプボタン押下時のコールバック
  final VoidCallback onHelp;

  /// ギャラリーから画像選択時のコールバック
  final VoidCallback? onPickFromGallery;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 16,
          left: 16,
          right: 16,
          bottom: 16,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.cameraBackground.withValues(alpha: 0.7),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close,
                  color: AppColors.cameraForeground, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                '値札を撮影',
                style: TextStyle(
                  color: AppColors.cameraForeground,
                  fontSize:
                      Theme.of(context).textTheme.headlineMedium?.fontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (onPickFromGallery != null)
              IconButton(
                onPressed: onPickFromGallery,
                icon: const Icon(Icons.image_outlined,
                    color: AppColors.cameraForeground),
                tooltip: '画像から読み取り',
              ),
            IconButton(
              onPressed: onHelp,
              icon: const Icon(Icons.help_outline,
                  color: AppColors.cameraForeground),
              tooltip: '撮影ガイドライン',
            ),
          ],
        ),
      ),
    );
  }
}
