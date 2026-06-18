/// 変更内容のカテゴリ
enum ChangeCategory {
  newFeature('新機能'),
  bugFix('バグ修正'),
  improvement('改善点'),
  other('その他');

  const ChangeCategory(this.label);
  final String label;
}

/// 変更内容のデータモデル
class ChangeItem {
  const ChangeItem({
    required this.description,
    required this.category,
  });

  final String description;
  final ChangeCategory category;
}

/// リリースノートのデータモデル
class ReleaseNote {
  const ReleaseNote({
    required this.version,
    required this.releaseDate,
    required this.changes,
    this.developerComment,
  });

  final String version;
  final DateTime releaseDate;
  final List<ChangeItem> changes;
  final String? developerComment;
}

/// 更新履歴データを管理するクラス
class ReleaseHistory {
  /// 更新履歴の静的データ（新しいバージョンを先頭に追加）
  static final List<ReleaseNote> _releaseNotes = [
    ReleaseNote(
      version: '1.6.1',
      releaseDate: DateTime(2026, 6, 18),
      changes: [
        const ChangeItem(
          description: '広告が正しく表示されない問題を修正しました。',
          category: ChangeCategory.bugFix,
        ),
      ],
    ),
    ReleaseNote(
      version: '1.6.0',
      releaseDate: DateTime(2026, 6, 18),
      changes: [
        const ChangeItem(
          description: 'ホーム画面・レシピ画面・各ダイアログのデザインを改善しました。',
          category: ChangeCategory.improvement,
        ),
        const ChangeItem(
          description: '「共有タブ」の名称を「同期タブ」に変更しました。',
          category: ChangeCategory.improvement,
        ),
        const ChangeItem(
          description: 'アイテムを編集して保存した際、自動で購入済みにならないことがある問題を修正しました。',
          category: ChangeCategory.bugFix,
        ),
        const ChangeItem(
          description: 'アプリ起動時にタブの表示が乱れることがある問題を修正しました。',
          category: ChangeCategory.bugFix,
        ),
        const ChangeItem(
          description: '設定変更後に取り消し線の表示が即座に反映されないことがある問題を修正しました。',
          category: ChangeCategory.bugFix,
        ),
        const ChangeItem(
          description: 'レシート読み取り（OCR）がタイムアウトしやすかった問題を修正しました。',
          category: ChangeCategory.bugFix,
        ),
        const ChangeItem(
          description: 'OCRの使用回数が、保存に失敗した場合でも消費されていた問題を修正しました。',
          category: ChangeCategory.bugFix,
        ),
        const ChangeItem(
          description: '同期タブで複数人が同時編集した際に、変更が巻き戻ることがある問題を修正しました。',
          category: ChangeCategory.bugFix,
        ),
        const ChangeItem(
          description: 'ゲストデータをアカウントに移行する際、データが消えるリスクを改善しました。',
          category: ChangeCategory.bugFix,
        ),
        const ChangeItem(
          description: '課金レシートをサーバー側でも検証し、不正利用を防止しました。',
          category: ChangeCategory.improvement,
        ),
        const ChangeItem(
          description: 'データ読み込みエラーが他のリストや項目に影響しないよう安定性を向上しました。',
          category: ChangeCategory.improvement,
        ),
        const ChangeItem(
          description: '書き込み失敗時に通知が表示されるよう改善しました。',
          category: ChangeCategory.improvement,
        ),
      ],
    ),
    ReleaseNote(
      version: '1.5.1',
      releaseDate: DateTime(2026, 3, 15),
      changes: [
        const ChangeItem(
          description: 'カメラ画面からギャラリーの写真も選択できるようになりました。',
          category: ChangeCategory.newFeature,
        ),
        const ChangeItem(
          description: 'レシート読み取り（OCR）の認識精度をさらに改善しました。',
          category: ChangeCategory.improvement,
        ),
        const ChangeItem(
          description: '入力フィールドに文字数の上限を設定し、安定性を向上しました。',
          category: ChangeCategory.improvement,
        ),
        const ChangeItem(
          description: '同期タブが起動時に重複して表示されるバグを修正しました。',
          category: ChangeCategory.bugFix,
        ),
        const ChangeItem(
          description: 'ログアウト後もプレミアム状態が維持されるバグを修正しました。',
          category: ChangeCategory.bugFix,
        ),
      ],
    ),
    ReleaseNote(
      version: '1.5.0',
      releaseDate: DateTime(2026, 3, 11),
      changes: [
        const ChangeItem(
          description: 'ログインしなくても「ゲストモード」でアプリを使えるようになりました。',
          category: ChangeCategory.newFeature,
        ),
        const ChangeItem(
          description: '初回起動時にアプリの使い方を案内するチュートリアルを追加しました。',
          category: ChangeCategory.newFeature,
        ),
        const ChangeItem(
          description: 'リストが空のときに操作ガイドを表示するようにしました。',
          category: ChangeCategory.newFeature,
        ),
        const ChangeItem(
          description: 'ウェルカム画面のデザインを一新しました。',
          category: ChangeCategory.improvement,
        ),
        const ChangeItem(
          description: 'ログイン画面やダークテーマの配色をより見やすく改善しました。',
          category: ChangeCategory.improvement,
        ),
        const ChangeItem(
          description: '合計金額の文字色をより見やすく調整しました。',
          category: ChangeCategory.improvement,
        ),
        const ChangeItem(
          description: 'OCR（レシート読み取り）の残り回数がボタン上にバッジで表示されるようになりました。',
          category: ChangeCategory.improvement,
        ),
        const ChangeItem(
          description: '全画面広告を廃止し、快適な操作感になりました。',
          category: ChangeCategory.improvement,
        ),
        const ChangeItem(
          description: 'プレミアム紹介画面をリニューアルしました。',
          category: ChangeCategory.improvement,
        ),
        const ChangeItem(
          description: 'ゲストモードのデータがアプリ終了後に消えてしまう問題を修正しました。',
          category: ChangeCategory.bugFix,
        ),
        const ChangeItem(
          description: 'テーマ選択画面の「制限中」バッジが正しく表示されない問題を修正しました。',
          category: ChangeCategory.bugFix,
        ),
        const ChangeItem(
          description: '起動時のデータ読み込みが競合する問題を修正しました。',
          category: ChangeCategory.bugFix,
        ),
        const ChangeItem(
          description: 'レシピ解析機能の不具合を修正しました。',
          category: ChangeCategory.bugFix,
        ),
      ],
    ),
    ReleaseNote(
      version: '1.4.0',
      releaseDate: DateTime(2025, 12, 20),
      changes: [
        const ChangeItem(
          description: 'タブ追加ボタンとリスト追加ボタンにラベルを追加し、区別しやすくしました。',
          category: ChangeCategory.improvement,
        ),
        const ChangeItem(
          description: 'アプリ全体の動作速度を改善しました。',
          category: ChangeCategory.improvement,
        ),
        const ChangeItem(
          description: 'データの同期が途切れた際に自動で再接続するようにしました。',
          category: ChangeCategory.improvement,
        ),
        const ChangeItem(
          description: 'Googleログインが失敗する場合がある問題を修正しました。',
          category: ChangeCategory.bugFix,
        ),
        const ChangeItem(
          description: 'レシピ取り込みで調味料がリストに追加されない問題を修正しました。',
          category: ChangeCategory.bugFix,
        ),
        const ChangeItem(
          description: 'プレミアム購入済みなのに「無料でお試し」バッジが表示される問題を修正しました。',
          category: ChangeCategory.bugFix,
        ),
        const ChangeItem(
          description: 'リストを一括削除した際に表示が一瞬乱れる問題を修正しました。',
          category: ChangeCategory.bugFix,
        ),
        const ChangeItem(
          description: 'リスト並べ替え時のカード表示の不具合を修正しました。',
          category: ChangeCategory.bugFix,
        ),
      ],
    ),
    ReleaseNote(
      version: '1.3.1',
      releaseDate: DateTime(2025, 11, 10),
      changes: [
        const ChangeItem(
          description: '予算を変更した際に即座に画面に反映されるようになりました。',
          category: ChangeCategory.bugFix,
        ),
        const ChangeItem(
          description: '同期タブの合計金額が正しく更新されない問題を修正しました。',
          category: ChangeCategory.bugFix,
        ),
        const ChangeItem(
          description: 'タブ切り替え時の画面のちらつきを修正しました。',
          category: ChangeCategory.bugFix,
        ),
        const ChangeItem(
          description: 'ヘッダーの背景色を全画面で統一しました。',
          category: ChangeCategory.improvement,
        ),
        const ChangeItem(
          description: 'プレミアム特典の表示を実際の機能に合わせて整理しました。',
          category: ChangeCategory.improvement,
        ),
      ],
    ),
    ReleaseNote(
      version: '1.3.0',
      releaseDate: DateTime(2025, 11, 1),
      changes: [
        const ChangeItem(
          description: 'OCR（レシート読み取り）の認識精度が大幅に向上しました。',
          category: ChangeCategory.newFeature,
        ),
        const ChangeItem(
          description: 'レシピ取り込み機能を改善しました（料理名の保存、数量の自動計算など）。',
          category: ChangeCategory.improvement,
        ),
        const ChangeItem(
          description: '同期タブのデザインを見やすくグループ化しました。',
          category: ChangeCategory.improvement,
        ),
        const ChangeItem(
          description: 'OCR結果の確認画面が使いやすくなりました。',
          category: ChangeCategory.improvement,
        ),
        const ChangeItem(
          description: 'Web版に対応しました。',
          category: ChangeCategory.newFeature,
        ),
        const ChangeItem(
          description: '新バージョンのお知らせ機能を追加しました。',
          category: ChangeCategory.newFeature,
        ),
        const ChangeItem(
          description: 'Android環境でのレイアウト崩れを修正しました。',
          category: ChangeCategory.bugFix,
        ),
      ],
    ),
    ReleaseNote(
      version: '1.2.0',
      releaseDate: DateTime(2025, 10, 19),
      changes: [
        const ChangeItem(
          description: 'リスト長押しで自由に並べ替えできる機能を追加。',
          category: ChangeCategory.newFeature,
        ),
        const ChangeItem(
          description: '起動時のスプラッシュ画面でのアイコンがテーマに沿った色になるように変更。',
          category: ChangeCategory.improvement,
        ),
        const ChangeItem(
          description: 'まいカゴプレミアム加入画面がテーマに沿った色になるように変更。',
          category: ChangeCategory.improvement,
        ),
        const ChangeItem(
          description: '詳細設定がアプリを再起動しても、保持されるように修正。',
          category: ChangeCategory.bugFix,
        ),
        const ChangeItem(
          description: 'リストを編集する際、０を削除しなくても数字が入力できるように改善。',
          category: ChangeCategory.improvement,
        ),
        const ChangeItem(
          description: 'アイテム追加と編集のダイアログUIを統一。',
          category: ChangeCategory.improvement,
        ),
        const ChangeItem(
          description: '使い方ページをより最適でわかりやすい説明に変更。',
          category: ChangeCategory.improvement,
        ),
        const ChangeItem(
          description: 'リスト追加・編集のダイアログの入力欄の背景を白に変更。',
          category: ChangeCategory.improvement,
        ),
        const ChangeItem(
          description: 'タブを同期する際、アイコンを設定し、同期タブを区別しやすい機能を追加。',
          category: ChangeCategory.newFeature,
        ),
        const ChangeItem(
          description: '同期タブのマークをテーマにあった色になるように修正。',
          category: ChangeCategory.improvement,
        ),
        const ChangeItem(
          description: '同期タブで現在のタブの合計金額と同期グループ全体の合計金額の両方を表示するように改善。',
          category: ChangeCategory.improvement,
        ),
      ],
    ),
  ];

  /// 全てのリリースノートを取得（新しい順）
  static List<ReleaseNote> getAllReleaseNotes() {
    return List.from(_releaseNotes);
  }

  /// 最新のリリースノートを取得
  static ReleaseNote? getLatestReleaseNote() {
    if (_releaseNotes.isEmpty) return null;
    return _releaseNotes.first;
  }

  /// 指定されたバージョンのリリースノートを取得
  static ReleaseNote? getReleaseNoteByVersion(String version) {
    try {
      return _releaseNotes.firstWhere((note) => note.version == version);
    } catch (e) {
      return null;
    }
  }

  /// 現在のアプリバージョンと最新リリースノートのバージョンを比較
  static bool isCurrentVersionLatest(String currentVersion) {
    final latest = getLatestReleaseNote();
    if (latest == null) return true;
    return latest.version == currentVersion;
  }

  /// バージョン比較（semantic versioning）
  static int compareVersions(String version1, String version2) {
    final v1Parts = version1.split('.').map(int.parse).toList();
    final v2Parts = version2.split('.').map(int.parse).toList();

    // 短い方のバージョンを0で埋める
    while (v1Parts.length < v2Parts.length) {
      v1Parts.add(0);
    }
    while (v2Parts.length < v1Parts.length) {
      v2Parts.add(0);
    }

    for (int i = 0; i < v1Parts.length; i++) {
      if (v1Parts[i] > v2Parts[i]) return 1;
      if (v1Parts[i] < v2Parts[i]) return -1;
    }

    return 0;
  }
}
