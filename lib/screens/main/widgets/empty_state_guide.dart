import 'package:flutter/material.dart';

// ── 空状態ガイドの内容（未購入／購入済み共通定義）─────────────
const _incIcon = Icons.shopping_cart_outlined;
const _incTitle = 'リストが\nまだありません';
const _incDesc = '「リスト追加」を\nタップ';

const _comIcon = Icons.swipe_right_rounded;
const _comTitle = 'スワイプして\n購入済みへ';
const _comDesc = '金額に\n反映されます';

const double _iconSize = 72;

// タイトル／説明のスタイルは一体版・単独版で共通化（DRY）
TextStyle _titleStyle(ThemeData theme) => TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.7),
    );

TextStyle _descStyle(ThemeData theme) => TextStyle(
      fontSize: 14,
      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.55),
    );

/// 未購入・購入済みが**両方とも空**のときに表示する左右一体ガイド。
///
/// 左右を「アイコン行・タイトル行・説明行・フッター行」という行単位で
/// 並べる（[_row]）。各行は [Row] + 左右 [Expanded] なので、行内の
/// 左右セルが必ず同じ高さ枠を持ち、[Center] で中央配置すれば縦位置が
/// ぴったり揃う。中央の区切り線は [Stack] 背景にコンテンツ高さで通す。
class EmptyStateGuide extends StatelessWidget {
  const EmptyStateGuide({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Stack(
      children: [
        // 中央の区切り線（リストエリアの縦いっぱい・通常時と同じ長さ）
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 1,
                height: double.infinity,
                child: ColoredBox(color: theme.dividerColor),
              ),
            ),
          ),
        ),
        // 左右一体グリッド（縦中央）
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // アイコン行
                _row(
                  left: Icon(
                    _incIcon,
                    size: _iconSize,
                    color: primary.withValues(alpha: 0.7),
                  ),
                  right: Icon(
                    _comIcon,
                    size: _iconSize,
                    color: primary.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 16),
                // タイトル行
                _row(
                  left: Text(_incTitle,
                      textAlign: TextAlign.center, style: _titleStyle(theme)),
                  right: Text(_comTitle,
                      textAlign: TextAlign.center, style: _titleStyle(theme)),
                ),
                const SizedBox(height: 8),
                // 説明行
                _row(
                  left: Text(_incDesc,
                      textAlign: TextAlign.center, style: _descStyle(theme)),
                  right: Text(_comDesc,
                      textAlign: TextAlign.center, style: _descStyle(theme)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 1行ぶんの左右セル。各セルを [Center] で中央寄せし、間に区切り線ぶんの
  /// 1pxを空ける（線そのものは [Stack] 背景が描画）。
  Widget _row({required Widget left, required Widget right}) {
    return Row(
      children: [
        Expanded(child: Center(child: left)),
        const SizedBox(width: 1),
        Expanded(child: Center(child: right)),
      ],
    );
  }
}

/// 片方のリストだけが空のときに、その側へ単独表示するガイド。
///
/// 隣はアイテムリストなので左右を揃える必要はなく、シンプルな縦並び。
class EmptyStateGuidePanel extends StatelessWidget {
  const EmptyStateGuidePanel({super.key, required this.isIncomplete});

  /// true=未購入側（カート＋下矢印）／ false=購入済み側（スワイプ）
  final bool isIncomplete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final inc = isIncomplete;

    // アイコン：未購入はカート、購入済みはスワイプ
    final Widget icon = Icon(
      inc ? _incIcon : _comIcon,
      size: _iconSize,
      color: primary.withValues(alpha: 0.7),
    );

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(height: 16),
          Text(inc ? _incTitle : _comTitle,
              textAlign: TextAlign.center, style: _titleStyle(theme)),
          const SizedBox(height: 8),
          Text(inc ? _incDesc : _comDesc,
              textAlign: TextAlign.center, style: _descStyle(theme)),
        ],
      ),
    );
  }
}
