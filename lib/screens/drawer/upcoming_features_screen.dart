import 'package:flutter/material.dart';
import 'package:maikago/services/settings_theme.dart';

/// 今後の新機能画面
/// アプリに今後追加される予定の機能リストを表示
class UpcomingFeaturesScreen extends StatelessWidget {
  const UpcomingFeaturesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('今後の新機能'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: ListView(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).padding.bottom + 16,
        ),
        children: [
          _buildHeader(context),
          const SizedBox(height: 24),
          _buildFeatureList(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.lightbulb_outline_rounded,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            '開発中の新機能',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'まいカゴをより便利にする機能を開発中です。\nご期待ください！',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureList(BuildContext context) {
    final features = [
      // 開発中の機能（上に表示）
      {
        'title': 'カテゴリ機能',
        'description': '商品をカテゴリ別に分類して管理できるようになります',
        'icon': Icons.category_rounded,
        'status': '開発中',
        'iconColor': AppColors.featureBlue,
      },
      {
        'title': '買い物履歴',
        'description': '過去の買い物リストを確認できるようになります',
        'icon': Icons.history_rounded,
        'status': '開発中',
        'iconColor': AppColors.featureMaterialGreen,
      },
      // 計画中の機能（下に表示）
      {
        'title': '冷蔵庫リスト',
        'description': '家にある食材を管理して、在庫を把握できます',
        'icon': Icons.kitchen_rounded,
        'status': '計画中',
        'iconColor': AppColors.featureCyan,
      },
      {
        'title': 'AI献立考案機能',
        'description': '冷蔵庫の食材からAIが最適な献立を提案します',
        'icon': Icons.restaurant_menu_rounded,
        'status': '計画中',
        'iconColor': AppColors.featureDeepPurple,
      },
      {
        'title': '通知機能',
        'description': '買い物の予定日や忘れ物を通知でお知らせします',
        'icon': Icons.notifications_rounded,
        'status': '計画中',
        'iconColor': AppColors.featurePurple,
      },
      {
        'title': 'バーコードスキャン',
        'description': '商品のバーコードをスキャンして自動で商品名を入力',
        'icon': Icons.qr_code_scanner_rounded,
        'status': '計画中',
        'iconColor': AppColors.featureRed,
      },
      {
        'title': 'レシート機能',
        'description': 'レシートを撮影して自動でリストを作成',
        'icon': Icons.receipt_rounded,
        'status': '計画中',
        'iconColor': AppColors.featureTeal,
      },
      {
        'title': '統計機能',
        'description': '買い物の傾向や支出をグラフで確認できます',
        'icon': Icons.analytics_rounded,
        'status': '計画中',
        'iconColor': AppColors.featureIndigo,
      },
      {
        'title': 'お得比較機能',
        'description': '重さや価格を入力することで、複数の商品を比較して、どちらがお得か瞬時にわかる機能',
        'icon': Icons.compare_arrows_rounded,
        'status': '計画中',
        'iconColor': AppColors.featureAmber,
      },
      {
        'title': 'お気に入り商品管理',
        'description': 'よく買う商品を「お気に入り」に登録 → ワンタップでリストに追加',
        'icon': Icons.favorite_rounded,
        'status': '計画中',
        'iconColor': AppColors.featurePink,
      },
      {
        'title': '買い物スケジュール機能',
        'description': '買い物日や曜日ごとのルーチン（例：火曜は特売日）を記録。毎週同じリストをテンプレートとして使える',
        'icon': Icons.calendar_today_rounded,
        'status': '計画中',
        'iconColor': AppColors.featureLightBlue,
      },
      {
        'title': '定期購入リスト',
        'description': '定期的に買う商品を登録しておき、1週間・2週間などの周期で自動追加。必需品の買い忘れを防ぐ',
        'icon': Icons.repeat_rounded,
        'status': '計画中',
        'iconColor': AppColors.featureLightGreen,
      },
      {
        'title': '価格推移トラッキング',
        'description': '毎回の買い物で記録した価格を保存。グラフで「この商品の値段は最近上がってる／下がってる」が見える',
        'icon': Icons.trending_up_rounded,
        'status': '計画中',
        'iconColor': AppColors.featureDeepOrange,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '予定されている機能',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ...features.map((feature) => _buildFeatureCard(context, feature)),
      ],
    );
  }

  Widget _buildFeatureCard(BuildContext context, Map<String, dynamic> feature) {
    // 開発状況に応じた色を決定
    final isInDevelopment = feature['status'] == '開発中';
    final statusColor = isInDevelopment
        ? AppColors.statusInDevelopment
        : AppColors.statusPlanned;
    final iconColor = feature['iconColor'] as Color;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(feature['icon'], color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          feature['title'],
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          feature['status'],
                          style: TextStyle(
                            fontSize:
                                Theme.of(context).textTheme.bodySmall?.fontSize,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    feature['description'],
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
