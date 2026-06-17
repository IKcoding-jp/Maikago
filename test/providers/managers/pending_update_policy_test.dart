import 'package:flutter_test/flutter_test.dart';
import 'package:maikago/providers/managers/pending_update_policy.dart';

void main() {
  // 配信窓10秒・書き込み中の安全上限60秒（既定値と同じ）
  const policy = PendingUpdatePolicy(
    deliveryWindow: Duration(seconds: 10),
    maxInFlight: Duration(seconds: 60),
  );
  // 固定の基準時刻（DateTime.now()を使わず決定的にする）
  final t0 = DateTime(2026, 1, 1, 12, 0, 0);

  group('PendingUpdatePolicy.isProtected', () {
    test('保護記録が無い(markedAt=null)ならリモートを採用する', () {
      expect(
        policy.isProtected(markedAt: null, inFlight: false, now: t0),
        isFalse,
      );
    });

    test('書き込み中なら配信窓(10秒)を超えてもローカルを守る（書き込み遅延の核心・issue #160）', () {
      // 編集から30秒経過＝旧実装では10秒で保護が切れて巻き戻った状況。
      final now = t0.add(const Duration(seconds: 30));
      expect(
        policy.isProtected(markedAt: t0, inFlight: true, now: now),
        isTrue,
      );
    });

    test('書き込み完了後は配信窓(10秒)以内ならローカルを守る', () {
      final now = t0.add(const Duration(seconds: 5));
      expect(
        policy.isProtected(markedAt: t0, inFlight: false, now: now),
        isTrue,
      );
    });

    test('書き込み完了後、配信窓(10秒)を過ぎたらリモートを採用する', () {
      final now = t0.add(const Duration(seconds: 11));
      expect(
        policy.isProtected(markedAt: t0, inFlight: false, now: now),
        isFalse,
      );
    });

    test('書き込みがハングしても安全上限(60秒)を超えたら保護を諦めリモートを採用する', () {
      final now = t0.add(const Duration(seconds: 61));
      expect(
        policy.isProtected(markedAt: t0, inFlight: true, now: now),
        isFalse,
      );
    });

    test('境界値：書き込み完了からちょうど配信窓(10秒)時点は保護しない（未満のみ保護）', () {
      final now = t0.add(const Duration(seconds: 10));
      expect(
        policy.isProtected(markedAt: t0, inFlight: false, now: now),
        isFalse,
      );
    });
  });

  group('mergePreferringProtectedLocal', () {
    test('保護中のIDはローカル値を採用し、非保護のIDはリモート値を採用する', () {
      const remote = [_E('a', 'remote'), _E('b', 'remote')];
      const local = [_E('a', 'local'), _E('b', 'local')];

      final merged = mergePreferringProtectedLocal<_E>(
        remote: remote,
        local: local,
        idOf: (e) => e.id,
        isProtected: (id) => id == 'a', // aだけ保護
      );

      expect(merged, const [_E('a', 'local'), _E('b', 'remote')]);
    });

    test('保護中でもローカルに存在しないIDはリモート値を採用する', () {
      const remote = [_E('a', 'remote')];
      const local = <_E>[];

      final merged = mergePreferringProtectedLocal<_E>(
        remote: remote,
        local: local,
        idOf: (e) => e.id,
        isProtected: (id) => true,
      );

      expect(merged, const [_E('a', 'remote')]);
    });

    test('リモートに無いIDは結果に含まれない（リモートが正のリスト）', () {
      const remote = [_E('a', 'remote')];
      const local = [_E('a', 'local'), _E('deleted', 'local')];

      final merged = mergePreferringProtectedLocal<_E>(
        remote: remote,
        local: local,
        idOf: (e) => e.id,
        isProtected: (id) => true,
      );

      expect(merged, const [_E('a', 'local')]);
    });
  });
}

/// テスト用の最小要素（id と中身 tag を持つ）。
class _E {
  const _E(this.id, this.tag);
  final String id;
  final String tag;

  @override
  bool operator ==(Object other) =>
      other is _E && other.id == id && other.tag == tag;

  @override
  int get hashCode => Object.hash(id, tag);
}
