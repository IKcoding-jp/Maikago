import 'package:flutter/foundation.dart';

/// 楽観的更新のバウンス抑止ポリシー（純粋ロジック・テスト容易）。
///
/// issue #160: 保護を「時間ベース（編集から固定10秒）」から
/// 「書き込み完了ベース」に変更する。
/// - 書き込みがまだ完了していない間（[inFlight]）は、経過時間に関係なく
///   ローカルを守る。書き込み遅延が長くても自分の編集が巻き戻らない。
/// - 書き込み完了後は、配信遅延ぶん（[deliveryWindow]）だけローカルを守る。
/// - 書き込みがハングしても恒久ロックにならないよう、[maxInFlight] で上限を設ける。
@immutable
class PendingUpdatePolicy {
  const PendingUpdatePolicy({
    this.deliveryWindow = const Duration(seconds: 10),
    this.maxInFlight = const Duration(seconds: 60),
  });

  /// 書き込み完了後、配信遅延ぶんローカルを優先し続ける窓。
  final Duration deliveryWindow;

  /// 書き込みが完了しない（ハングした）場合に保護を諦める上限。
  final Duration maxInFlight;

  /// このIDのローカル値を保護（リモートで上書きしない）すべきか。
  ///
  /// [markedAt] は保護開始時刻。編集時にセットし、書き込み完了時に押し直す。
  /// [inFlight] は Firestore 書き込みがまだ完了していない場合 true。
  /// [now] は現在時刻（テストのため注入可能）。
  bool isProtected({
    required DateTime? markedAt,
    required bool inFlight,
    required DateTime now,
  }) {
    if (markedAt == null) return false;
    final elapsed = now.difference(markedAt);
    if (inFlight) {
      // 書き込み完了まで（安全上限付きで）ローカル優先。経過時間では切らない。
      return elapsed < maxInFlight;
    }
    // 完了後は配信遅延ぶんだけ守る。
    return elapsed < deliveryWindow;
  }
}

/// リモートのリストを正としつつ、保護中のIDだけローカル値を残してマージする。
///
/// items / shops の双方で同一の処理を行うため共通化（issue #160）。
/// - [remote] が結果の母集合（リモートに無いIDは結果に含まれない）。
/// - [isProtected] が true のIDは、ローカルに存在すればローカル値を採用する。
/// - 保護中でもローカルに存在しないIDはリモート値を採用する。
List<T> mergePreferringProtectedLocal<T>({
  required List<T> remote,
  required List<T> local,
  required String Function(T) idOf,
  required bool Function(String id) isProtected,
}) {
  final localById = <String, T>{for (final l in local) idOf(l): l};
  final merged = <T>[];
  for (final r in remote) {
    final id = idOf(r);
    if (isProtected(id)) {
      merged.add(localById[id] ?? r);
    } else {
      merged.add(r);
    }
  }
  return merged;
}
