import 'package:dev_stack/core/services/log_service.dart';
import 'package:dev_stack/features/apps/data/app_service_manager.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression test for the "Update failed: Deletion failed, Access is denied
/// (errno 5)" crash that occurred when swapping a PHP version.
///
/// Root cause: `forceKillPid` issued `taskkill /F /PID <pid>` WITHOUT `/T`.
/// When the recorded service PID was a launcher/wrapper (e.g. a hidden console
/// host) rather than the real `php-cgi.exe`, only the wrapper died — the child
/// php-cgi kept its DLL handles open inside the version folder, so the
/// recursive directory delete hit Access Denied.
void main() {
  group('AppServiceManager.forceKillPid process-tree kill', () {
    test(
      'uses /T so the whole process tree dies, not just the wrapper PID',
      () {
        final recorded = <List<String>>[];
        Future<List<String>> captureRunner(
          String exec,
          List<String> args,
        ) async {
          recorded.add([exec, ...args]);
          return <String>[];
        }

        final manager = AppServiceManager(AppLogger, runProcess: captureRunner);

        manager.forceKillPid('php84', 12345);

        expect(recorded, hasLength(1));
        expect(recorded[0].first, 'taskkill');
        // /F = force, /T = tree (must include children), /PID <pid>
        expect(
          recorded[0],
          containsAll(const <String>['/F', '/T', '/PID', '12345']),
        );
      },
    );

    test('skips kill when no PID is recorded (pid <= 0)', () {
      final recorded = <List<String>>[];
      final manager = AppServiceManager(
        AppLogger,
        runProcess: (exec, args) async {
          recorded.add([exec, ...args]);
          return <String>[];
        },
      );

      manager.forceKillPid('php84', 0);

      expect(recorded, isEmpty, reason: 'no PID → nothing to kill');
    });

    test('is a no-op on non-Windows hosts (no taskkill)', () {
      final recorded = <List<String>>[];
      final manager = AppServiceManager(
        AppLogger,
        platformIsWindows: () => false,
        runProcess: (exec, args) async {
          recorded.add([exec, ...args]);
          return <String>[];
        },
      );

      manager.forceKillPid('php84', 99999);

      expect(recorded, isEmpty);
    });
  });
}
