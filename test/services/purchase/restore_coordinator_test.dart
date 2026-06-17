import 'package:flutter_test/flutter_test.dart';
import 'package:maikago/services/purchase/restore_coordinator.dart';

void main() {
  group('RestoreCoordinator', () {
    test('signalRestoredが呼ばれるとtrueを返す', () async {
      final coordinator =
          RestoreCoordinator(timeout: const Duration(seconds: 5));

      final result = await coordinator.wait(() async {
        // 復元イベントが非同期に届く想定
        Future.delayed(
          const Duration(milliseconds: 10),
          coordinator.signalRestored,
        );
      });

      expect(result, true);
    });

    test('シグナルが来なければタイムアウトでfalseを返す', () async {
      final coordinator =
          RestoreCoordinator(timeout: const Duration(milliseconds: 50));

      final result = await coordinator.wait(() async {});

      expect(result, false);
    });

    test('タイムアウト後はisWaitingがfalse（Completerが放置されない）', () async {
      final coordinator =
          RestoreCoordinator(timeout: const Duration(milliseconds: 50));

      await coordinator.wait(() async {});

      expect(coordinator.isWaiting, false);
    });

    test('タイムアウト→再試行が正常動作する（完了条件②）', () async {
      final coordinator =
          RestoreCoordinator(timeout: const Duration(milliseconds: 50));

      // 1回目: シグナルなし → タイムアウトでfalse
      final first = await coordinator.wait(() async {});
      expect(first, false);

      // 2回目: 再試行でシグナルあり → true（前回の残骸に邪魔されない）
      final second = await coordinator.wait(() async {
        coordinator.signalRestored();
      });
      expect(second, true);
    });

    test('待機していないときのsignalRestoredは例外を投げない', () {
      final coordinator = RestoreCoordinator();

      expect(coordinator.signalRestored, returnsNormally);
    });

    test('startRestoreが例外を投げてもisWaitingはfalseにリセットされる', () async {
      final coordinator =
          RestoreCoordinator(timeout: const Duration(milliseconds: 50));

      await expectLater(
        coordinator.wait(() async => throw Exception('restore failed')),
        throwsException,
      );
      expect(coordinator.isWaiting, false);
    });
  });
}
