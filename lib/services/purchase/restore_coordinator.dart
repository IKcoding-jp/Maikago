import 'dart:async';

/// 「購入を復元」処理の Completer ライフサイクルを管理する。
///
/// in_app_purchase の `restorePurchases()` は復元結果を purchaseStream 経由で
/// 非同期に通知するため、呼び出し側は「復元イベントが届く」か「タイムアウト」の
/// いずれかを待つ必要がある。本クラスはその待機・完了・タイムアウト時の
/// リセットを一元管理し、タイムアウト後の再試行が正常動作することを保証する
/// （Issue #163: タイムアウト時に Completer が放置され再試行が不安定になる問題）。
class RestoreCoordinator {
  RestoreCoordinator({this.timeout = const Duration(seconds: 30)});

  /// 復元完了を待つ最大時間。
  final Duration timeout;

  Completer<bool>? _completer;

  /// 現在、復元の完了を待機中かどうか。
  bool get isWaiting => _completer != null && !_completer!.isCompleted;

  /// 復元を開始し、完了（[signalRestored]）またはタイムアウトまで待つ。
  ///
  /// [startRestore] は実際の `restorePurchases()` 呼び出し。
  /// 戻り値は復元成功なら true、タイムアウトなら false。
  ///
  /// タイムアウト・完了・例外のいずれの経路でも、最後に内部状態を必ず
  /// リセットするため、続けて再呼び出ししても前回の残骸に邪魔されない。
  Future<bool> wait(Future<void> Function() startRestore) async {
    final completer = Completer<bool>();
    _completer = completer;
    try {
      await startRestore();
      return await completer.future.timeout(
        timeout,
        onTimeout: () => false,
      );
    } finally {
      _completer = null;
    }
  }

  /// 復元イベントを受信したときに呼ぶ。待機中の [wait] を true で完了させる。
  /// 待機していない場合・既に完了済みの場合は何もしない。
  void signalRestored() {
    final completer = _completer;
    if (completer != null && !completer.isCompleted) {
      completer.complete(true);
    }
  }
}
