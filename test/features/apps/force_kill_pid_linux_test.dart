import 'dart:io';

import 'package:dev_stack/core/services/log_service.dart';
import 'package:dev_stack/features/apps/data/app_service_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppServiceManager.forceKillPid Linux process group kill', () {
    test(
      'Case 1: Linux: process group kill succeeds, does not trigger fallback',
      () async {
        final calls = <List<String>>[];
        final manager = AppServiceManager(AppLogger);

        await manager.forceKillPid(
          'nginx',
          1234,
          isWindows: false,
          runProcess: (exec, args) async {
            calls.add([exec, ...args]);
            return ProcessResult(1234, 0, '', '');
          },
        );

        expect(calls, hasLength(1));
        expect(calls.first, ['kill', '-9', '--', '-1234']);
      },
    );

    test(
      'Case 2: Linux: process group kill returns non-zero exitCode, falls back to single PID kill',
      () async {
        final calls = <List<String>>[];
        final manager = AppServiceManager(AppLogger);

        await manager.forceKillPid(
          'nginx',
          1234,
          isWindows: false,
          runProcess: (exec, args) async {
            calls.add([exec, ...args]);
            if (args.contains('--')) {
              return ProcessResult(1234, 1, '', 'No such process group');
            }
            return ProcessResult(1234, 0, '', '');
          },
        );

        expect(calls, hasLength(2));
        expect(calls[0], ['kill', '-9', '--', '-1234']);
        expect(calls[1], ['kill', '-9', '1234']);
      },
    );

    test(
      'Case 3: Linux: process group kill throws exception, falls back to single PID kill',
      () async {
        final calls = <List<String>>[];
        final manager = AppServiceManager(AppLogger);

        await manager.forceKillPid(
          'nginx',
          1234,
          isWindows: false,
          runProcess: (exec, args) async {
            calls.add([exec, ...args]);
            if (args.contains('--')) {
              throw ProcessException(
                'kill',
                args,
                'Operation not permitted',
                1,
              );
            }
            return ProcessResult(1234, 0, '', '');
          },
        );

        expect(calls, hasLength(2));
        expect(calls[0], ['kill', '-9', '--', '-1234']);
        expect(calls[1], ['kill', '-9', '1234']);
      },
    );

    test('Case 4: Windows: calls taskkill with /F /T /PID', () async {
      final calls = <List<String>>[];
      final manager = AppServiceManager(AppLogger);

      await manager.forceKillPid(
        'php84',
        5678,
        isWindows: true,
        runProcess: (exec, args) async {
          calls.add([exec, ...args]);
          return ProcessResult(5678, 0, '', '');
        },
      );

      expect(calls, hasLength(1));
      expect(calls.first, ['taskkill', '/F', '/T', '/PID', '5678']);
    });

    test('Case 5: PID <= 0: skips kill without executing any commands', () async {
      final calls = <List<String>>[];
      final manager = AppServiceManager(AppLogger);

      await manager.forceKillPid(
        'nginx',
        0,
        isWindows: false,
        runProcess: (exec, args) async {
          calls.add([exec, ...args]);
          return ProcessResult(0, 0, '', '');
        },
      );

      await manager.forceKillPid(
        'nginx',
        -5,
        isWindows: false,
        runProcess: (exec, args) async {
          calls.add([exec, ...args]);
          return ProcessResult(-5, 0, '', '');
        },
      );

      expect(calls, isEmpty);
    });

    test(
      'Linux: fallback kill throws exception, caught and logged without crashing',
      () async {
        final calls = <List<String>>[];
        final manager = AppServiceManager(AppLogger);

        await expectLater(
          manager.forceKillPid(
            'nginx',
            1234,
            isWindows: false,
            runProcess: (exec, args) async {
              calls.add([exec, ...args]);
              throw ProcessException('kill', args, 'Failed', 1);
            },
          ),
          completes,
        );

        expect(calls, hasLength(2));
      },
    );
  });
}
