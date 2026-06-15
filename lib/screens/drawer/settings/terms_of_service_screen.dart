import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:maikago/services/settings_theme.dart';
import 'package:maikago/screens/drawer/settings/theme_select_screen.dart';

/// 利用規約画面
class TermsOfServiceScreen extends StatefulWidget {
  const TermsOfServiceScreen({
    super.key,
    required this.currentTheme,
    required this.currentFont,
    required this.currentFontSize,
    this.theme,
  });

  final String currentTheme;
  final String currentFont;
  final double currentFontSize;
  final ThemeData? theme;

  @override
  State<TermsOfServiceScreen> createState() => _TermsOfServiceScreenState();
}

class _TermsOfServiceScreenState extends State<TermsOfServiceScreen> {
  late SettingsState _settingsState;

  @override
  void initState() {
    super.initState();
    _settingsState = SettingsState();
    _settingsState.setInitialState(
      theme: widget.currentTheme,
      font: widget.currentFont,
      fontSize: widget.currentFontSize,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _settingsState,
      child: Consumer<SettingsState>(
        builder: (context, settingsState, _) {
          final currentTheme = _getCurrentTheme(settingsState);
          return Theme(
            data: currentTheme,
            child: Scaffold(
              appBar: _buildAppBar(settingsState),
              body: _buildBody(settingsState),
            ),
          );
        },
      ),
    );
  }

  /// アプリバーを構築
  PreferredSizeWidget _buildAppBar(SettingsState settingsState) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.pop(),
      ),
      title: Text(
        '利用規約',
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color:
                  SettingsTheme.getOnPrimaryColor(settingsState.selectedTheme),
            ),
      ),
      backgroundColor:
          SettingsTheme.getPrimaryColor(settingsState.selectedTheme),
      foregroundColor:
          SettingsTheme.getOnPrimaryColor(settingsState.selectedTheme),
      iconTheme: IconThemeData(
        color: SettingsTheme.getOnPrimaryColor(settingsState.selectedTheme),
      ),
      elevation: 0,
    );
  }

  /// ボディを構築
  Widget _buildBody(SettingsState settingsState) {
    return Container(
      color: SettingsTheme.getSurfaceColor(settingsState.selectedTheme),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).padding.bottom + 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(settingsState),
            const SizedBox(height: 24),
            _buildTermsContent(settingsState),
          ],
        ),
      ),
    );
  }

  /// ヘッダーを構築
  Widget _buildHeader(SettingsState settingsState) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 2,
      color: (widget.theme ?? _getCurrentTheme(settingsState)).cardColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: SettingsTheme.getPrimaryColor(
                      settingsState.selectedTheme),
                  child: Icon(
                    Icons.description_rounded,
                    color: SettingsTheme.getOnPrimaryColor(
                        settingsState.selectedTheme),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '利用規約',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: SettingsTheme.getTextColor(
                            settingsState.selectedTheme),
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '最終更新日: 2025年1月',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: SettingsTheme.getSubtextColor(
                        settingsState.selectedTheme),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  /// 利用規約の内容を構築
  Widget _buildTermsContent(SettingsState settingsState) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 2,
      color: (widget.theme ?? _getCurrentTheme(settingsState)).cardColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              title: '第1条（はじめに）',
              content:
                  '本利用規約（以下「本規約」）は、Maikago（以下「本アプリ」）の利用条件を定めるものです。本アプリを利用するすべてのユーザー（以下「ユーザー」）は、本規約に同意したものとみなされます。本規約に同意できない場合は、本アプリの利用を直ちに中止してください。',
              settingsState: settingsState,
            ),
            const SizedBox(height: 20),
            _buildSection(
              title: '第2条（アプリの概要）',
              content: 'Maikagoは、毎日の買い物をサポートするためのアプリケーションです。主な機能は以下の通りです：\n\n'
                  '1. 買い物リストの作成・管理\n'
                  '2. 値札やバーコードのスキャンによる商品入力（OCR機能）\n'
                  '3. プレミアム機能によるカスタマイズ（有料サービス）',
              settingsState: settingsState,
            ),
            const SizedBox(height: 20),
            _buildSection(
              title: '第3条（利用条件）',
              content: '1. 利用資格\n'
                  '本アプリは、13歳以上の方が利用できます。未成年者が利用する場合は、必ず親権者等の法定代理人の同意を得て利用してください。\n\n'
                  '2. 動作環境\n'
                  '本アプリを利用するためには、インターネット接続環境およびカメラ機能（OCR機能利用時）を備えたスマートフォン等の端末が必要です。通信料はユーザーの負担となります。',
              settingsState: settingsState,
            ),
            const SizedBox(height: 20),
            _buildSection(
              title: '第4条（有料サービス）',
              content: '1. サービス内容と料金\n'
                  'プレミアムプランでは、広告の非表示、テーマカラーの変更、フォントの変更などが可能になります。具体的な料金およびサービス内容は、購入画面に表示されます。\n\n'
                  '2. 課金形態\n'
                  '有料サービスは「買い切り型」です。一度お支払いいただくことで、対象機能を無期限にご利用いただけます。\n\n'
                  '3. 支払い\n'
                  '利用料金の支払いは、Apple Inc.（App Store）またはGoogle LLC（Google Play）が提供する決済手段を通じて行われます。\n\n'
                  '4. 返金\n'
                  'デジタルコンテンツの性質上、法令により義務付けられる場合を除き、支払い完了後の返金には応じられません。',
              settingsState: settingsState,
            ),
            const SizedBox(height: 20),
            _buildSection(
              title: '第5条（禁止事項）',
              content: 'ユーザーは、本アプリの利用にあたり、以下の行為をしてはなりません。\n\n'
                  '1. 法令、公序良俗に反する行為\n'
                  '2. 本アプリの運営を妨害する行為、またはサーバーに過度な負荷をかける行為\n'
                  '3. リバースエンジニアリング、逆コンパイル等の解析行為\n'
                  '4. 虚偽の情報を登録する行為\n'
                  '5. 第三者の権利を侵害する行為',
              settingsState: settingsState,
            ),
            const SizedBox(height: 20),
            _buildSection(
              title: '第6条（免責事項）',
              content: '本アプリは「現状有姿」で提供され、開発者は以下の事項について保証しません。\n\n'
                  '1. 読み取り精度\n'
                  'レシートや値札の読み取り（OCR）機能および商品名解析機能はAIを利用しており、100%の正確性を保証するものではありません。必ずご自身で内容を確認してください。\n\n'
                  '2. データの保存\n'
                  '予期せぬ不具合や通信障害によりデータが消失する可能性があります。重要なデータはユーザー自身でバックアップをとる等の対策を推奨します。\n\n'
                  '3. 損害賠償\n'
                  '本アプリの利用によりユーザーに生じた損害について、開発者に故意または重過失がある場合を除き、開発者は責任を負わないものとします。',
              settingsState: settingsState,
            ),
            const SizedBox(height: 20),
            _buildSection(
              title: '第7条（知的財産権）',
              content:
                  '本アプリに含まれるプログラム、画像、デザイン、商標等の知的財産権は、開発者または正当な権利者に帰属します。ユーザーは、私的使用の範囲を超えてこれらを複製、転載、改変することはできません。',
              settingsState: settingsState,
            ),
            const SizedBox(height: 20),
            _buildSection(
              title: '第8条（プライバシーポリシー）',
              content: 'ユーザーの個人情報の取り扱いについては、別途定めるプライバシーポリシーに従います。',
              settingsState: settingsState,
            ),
            const SizedBox(height: 20),
            _buildSection(
              title: '第9条（規約の変更）',
              content:
                  '開発者は、必要と判断した場合、ユーザーに通知することなく本規約を変更できるものとします。変更後の規約は、本アプリ内に掲示された時点で効力を生じるものとし、以降の利用には変更後の規約が適用されます。',
              settingsState: settingsState,
            ),
            const SizedBox(height: 20),
            _buildSection(
              title: '第10条（準拠法・裁判管轄）',
              content:
                  '本規約は日本法に準拠して解釈されます。本アプリに関する紛争については、東京地方裁判所を第一審の専属的合意管轄裁判所とします。',
              settingsState: settingsState,
            ),
            const SizedBox(height: 20),
            _buildSection(
              title: 'お問い合わせ',
              content:
                  '本利用規約に関するお問い合わせは、以下までお願いいたします。\n\nメール: kensaku.ikeda04@gmail.com',
              settingsState: settingsState,
            ),
          ],
        ),
      ),
    );
  }

  /// セクションを構築
  Widget _buildSection({
    required String title,
    required String content,
    required SettingsState settingsState,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: SettingsTheme.getTextColor(settingsState.selectedTheme),
              ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color:
                    SettingsTheme.getSubtextColor(settingsState.selectedTheme),
                height: 1.6,
              ),
        ),
      ],
    );
  }

  /// 現在のテーマを取得
  ThemeData _getCurrentTheme(SettingsState settingsState) {
    return SettingsTheme.generateTheme(
      selectedTheme: settingsState.selectedTheme,
      selectedFont: settingsState.selectedFont,
      fontSize: settingsState.selectedFontSize,
    );
  }
}
