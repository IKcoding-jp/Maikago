import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:maikago/services/settings_theme.dart';
import 'package:maikago/utils/theme_utils.dart';

/// カメラ使用時のガイドラインと注意喚起ダイアログ
class CameraGuidelinesDialog extends StatefulWidget {
  const CameraGuidelinesDialog({
    super.key,
    this.showDontShowAgainCheckbox = true,
  });

  final bool showDontShowAgainCheckbox;

  @override
  State<CameraGuidelinesDialog> createState() => _CameraGuidelinesDialogState();
}

class _CameraGuidelinesDialogState extends State<CameraGuidelinesDialog> {
  bool _dontShowAgain = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // タイトル
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.camera_alt_rounded,
                      color: AppColors.primary, size: 28),
                  const SizedBox(width: 8),
                  Text(
                    '撮影時のご注意',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // スクロール可能なコンテンツ
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // 撮影のコツ
                      _buildCard(
                        color: AppColors.secondary,
                        icon: Icons.camera_alt_rounded,
                        title: '撮影のコツ',
                        child: Text(
                          '• 値札を正面から大きく撮影\n'
                          '• 文字がくっきり見えるようピントを合わせる\n'
                          '• 手ブレしないようしっかり構える',
                          style: TextStyle(
                            fontSize:
                                Theme.of(context).textTheme.bodySmall?.fontSize,
                            color: Theme.of(context).colorScheme.onSurface,
                            height: 1.5,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // 撮影マナー
                      _buildCard(
                        color: AppColors.accent,
                        icon: Icons.handshake_rounded,
                        title: '撮影マナー',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildMannerItem(
                              Icons.volume_off_rounded,
                              '他のお客様のご迷惑にならないよう静かに撮影してください。',
                            ),
                            const SizedBox(height: 6),
                            _buildMannerItem(
                              Icons.store_rounded,
                              '店舗の利用規約を確認し、撮影が禁止されている場合は控えてください。',
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // 読み取り精度について
                      _buildCard(
                        color: AppColors.primary,
                        icon: Icons.info_outline_rounded,
                        title: '読み取り精度について',
                        child: Text(
                          'カメラの画質やピント、値札の種類によっては、正しく読み取れず、リストが間違った名前や金額で表示されてしまうこともあります。その場合は手動で書き換えてください。',
                          style: TextStyle(
                            fontSize:
                                Theme.of(context).textTheme.bodySmall?.fontSize,
                            color: Theme.of(context).colorScheme.onSurface,
                            height: 1.5,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // プライバシーについて
                      _buildCard(
                        color: AppColors.tertiary,
                        icon: Icons.lock_rounded,
                        title: 'プライバシーについて',
                        child: Text(
                          '• 画像は端末内で処理され、外部に送信されません\n'
                          '• 商品名と価格の読み取りのみに使用されます',
                          style: TextStyle(
                            fontSize:
                                Theme.of(context).textTheme.bodySmall?.fontSize,
                            color: Theme.of(context).colorScheme.onSurface,
                            height: 1.5,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // 「二度と表示しない」チェックボックス
                      if (widget.showDontShowAgainCheckbox)
                        Row(
                          children: [
                            Checkbox(
                              value: _dontShowAgain,
                              onChanged: (value) {
                                setState(() {
                                  _dontShowAgain = value ?? false;
                                });
                              },
                              activeColor: AppColors.primary,
                            ),
                            Expanded(
                              child: Text(
                                '二度と表示しない',
                                style: TextStyle(
                                  fontSize: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.fontSize,
                                  color: Theme.of(context).subtextColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ボタン
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => context.pop({
                      'confirmed': false,
                      'dontShowAgain': widget.showDontShowAgainCheckbox
                          ? _dontShowAgain
                          : false,
                    }),
                    child: Text(
                      'キャンセル',
                      style: TextStyle(color: Theme.of(context).subtextColor),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => context.pop({
                      'confirmed': true,
                      'dontShowAgain': widget.showDontShowAgainCheckbox
                          ? _dontShowAgain
                          : false,
                    }),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                    child: const Text('了解して撮影開始'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard({
    required Color color,
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: Theme.of(context).textTheme.bodyMedium?.fontSize,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildMannerItem(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Theme.of(context).subtextColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: Theme.of(context).textTheme.bodySmall?.fontSize,
              color: Theme.of(context).colorScheme.onSurface,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
