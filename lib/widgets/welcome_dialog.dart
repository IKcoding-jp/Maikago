import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:maikago/services/settings_persistence.dart';
import 'package:maikago/services/settings_theme.dart';
import 'package:maikago/utils/theme_utils.dart';

class WelcomeDialog extends StatefulWidget {
  const WelcomeDialog({
    super.key,
    this.onCompleted,
  });

  final VoidCallback? onCompleted;

  @override
  State<WelcomeDialog> createState() => _WelcomeDialogState();
}

class _WelcomeDialogState extends State<WelcomeDialog>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  int _currentPage = 0;

  final List<WelcomePage> _pages = [
    WelcomePage(
      icon: Icons.favorite_rounded,
      title: 'まいカゴをインストールしてくれて\nありがとうございます！',
      description:
          'あなたの買い物ライフをより楽しく、\nより効率的にするお手伝いをさせていただきます。\n\nさあ、賢い買い物を始めましょう！',
      color: AppColors.primary, // パステルピンク
    ),
    WelcomePage(
      icon: Icons.savings_rounded,
      title: '賢い買い物で\n節約を実現',
      description:
          '買い物で節約するなら、あらかじめ買うものを決めておいて、\n値段を計算しながら買うことが大事です。\n\n無駄な出費を避け、予算オーバーを防ぎましょう！',
      color: AppColors.featureGreen, // ライトグリーン
    ),
    WelcomePage(
      icon: Icons.shopping_basket_rounded,
      title: 'メモと電卓の\n行き来はもう不要',
      description:
          'メモと電卓の行き来はめんどくさい。\nまいカゴはその機能が一体になったアプリです！\n\n買い物リストの作成から、\n合計金額の計算まで、すべてがここにあります。',
      color: AppColors.featureSky, // スカイブルー
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentPage++;
      });
    } else {
      _completeWelcome();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentPage--;
      });
    }
  }

  Future<void> _completeWelcome() async {
    await SettingsPersistence.setFirstLaunchComplete();
    if (mounted) {
      context.pop();
      widget.onCompleted?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 400;
    final isLargeScreen = screenSize.width > 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 24,
        vertical: isSmallScreen ? 24 : 32,
      ),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(
              maxWidth: isLargeScreen ? 500 : 400,
              maxHeight: screenSize.height * 0.65,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).cardShadowColor,
                  blurRadius: 25,
                  offset: const Offset(0, 12),
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ヘッダー部分
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 10 : 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(context).primaryColor,
                        Theme.of(context).primaryColor.withValues(alpha: 0.8),
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimary
                              .withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(
                          Icons.shopping_basket_rounded,
                          color: Theme.of(context).colorScheme.onPrimary,
                          size: isSmallScreen ? 28 : 32,
                        ),
                      ),
                      SizedBox(width: isSmallScreen ? 12 : 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'まいカゴへようこそ！',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontSize: isSmallScreen ? 18 : 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '買い物リスト管理アプリ',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontSize: isSmallScreen ? 12 : 14,
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ページビュー部分
                Flexible(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemCount: _pages.length,
                    itemBuilder: (context, index) {
                      final page = _pages[index];
                      return _buildPage(page, isSmallScreen);
                    },
                  ),
                ),

                // ページインジケーター
                Container(
                  padding: EdgeInsets.symmetric(
                    vertical: isSmallScreen ? 2 : 4,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: _currentPage == index ? 24 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: _currentPage == index
                              ? Theme.of(context).primaryColor
                              : Theme.of(context)
                                  .colorScheme
                                  .outline
                                  .withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  ),
                ),

                // ボタン部分
                Container(
                  padding: EdgeInsets.fromLTRB(
                    isSmallScreen ? 16 : 24,
                    0,
                    isSmallScreen ? 16 : 24,
                    isSmallScreen ? 6 : 8,
                  ),
                  child: Row(
                    children: [
                      if (_currentPage > 0)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _previousPage,
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                vertical: isSmallScreen ? 14 : 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              side: BorderSide(
                                color: Theme.of(context).primaryColor,
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              '戻る',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 14 : 16,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          ),
                        ),
                      if (_currentPage > 0)
                        SizedBox(width: isSmallScreen ? 12 : 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _nextPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor:
                                Theme.of(context).colorScheme.onPrimary,
                            padding: EdgeInsets.symmetric(
                              vertical: isSmallScreen ? 14 : 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 3,
                            shadowColor: Theme.of(
                              context,
                            ).primaryColor.withValues(alpha: 0.3),
                          ),
                          child: Text(
                            _currentPage == _pages.length - 1 ? '始める' : '次へ',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 14 : 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPage(WelcomePage page, bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 20,
        vertical: isSmallScreen ? 4 : 6,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // アイコン
          Container(
            width: isSmallScreen ? 60 : 80,
            height: isSmallScreen ? 60 : 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  page.color.withValues(alpha: 0.1),
                  page.color.withValues(alpha: 0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: page.color.withValues(alpha: 0.2),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Icon(
              page.icon,
              size: isSmallScreen ? 30 : 40,
              color: page.color,
            ),
          ),
          SizedBox(height: isSmallScreen ? 12 : 16),

          // タイトル
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isSmallScreen ? 18 : 22,
              fontWeight: FontWeight.bold,
              height: 1.3,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          SizedBox(height: isSmallScreen ? 8 : 12),

          // 説明文
          Text(
            page.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isSmallScreen ? 14 : 16,
              color: Theme.of(context).subtextColor,
              height: 1.5,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class WelcomePage {
  WelcomePage({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;
}
