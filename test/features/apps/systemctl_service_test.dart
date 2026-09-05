import 'dart:io';

import 'package:dev_stack/core/services/log_service.dart';
import 'package:dev_stack/features/apps/data/app_service_manager.dart';
import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AppModel createPhpApp({String appId = 'php82', String name = 'PHP 8.2'}) {
    return AppModel(
      appId: appId,
      name: name,
      categories: ['language'],
      groupName: 'php',
      installMethod: 'package_manager',
    );
  }

  group('AppServiceManager - PHP-FPM systemctl service management', () {
    test(
      'Case 1: Start user service successfully and probe is-active == active',
      () async {
        final calls = <List<String>>[];
        final manager = AppServiceManager(AppLogger);
        final app = createPhpApp();
        bool statusChanged = false;

        await manager.startPhpFpmViaSystemctlForTesting(
          app,
          onStatusChange: () => statusChanged = true,
          isLinux: true,
          runProcess: (exec, args) async {
            calls.add([exec, ...args]);
            if (args.contains('start')) {
              return ProcessResult(1, 0, '', '');
            }
            if (args.contains('is-active')) {
              return ProcessResult(2, 0, 'active\n', '');
            }
            if (args.contains('show')) {
              return ProcessResult(3, 0, '2468\n', '');
            }
            return ProcessResult(0, 0, '', '');
          },
        );

        expect(calls, hasLength(3));
        expect(calls[0], ['systemctl', '--user', 'start', 'php8.2-fpm']);
        expect(calls[1], ['systemctl', '--user', 'is-active', 'php8.2-fpm']);
        expect(calls[2], [
          'systemctl',
          '--user',
          'show',
          '--property=MainPID',
          '--value',
          'php8.2-fpm',
        ]);

        expect(app.serviceStatus, 'running');
        expect(app.servicePid, 2468);
        expect(statusChanged, isTrue);
        expect(manager.isRunning(app.appId), isTrue);
      },
    );

    test(
      'Case 2: User service returns exitCode != 0, automatically falls back to system service',
      () async {
        final calls = <List<String>>[];
        final manager = AppServiceManager(AppLogger);
        final app = createPhpApp();
        bool statusChanged = false;

        await manager.startPhpFpmViaSystemctlForTesting(
          app,
          onStatusChange: () => statusChanged = true,
          isLinux: true,
          runProcess: (exec, args) async {
            calls.add([exec, ...args]);
            if (args.contains('--user') && args.contains('start')) {
              return ProcessResult(1, 1, '', 'Failed to connect to user bus');
            }
            if (!args.contains('--user') && args.contains('start')) {
              return ProcessResult(2, 0, '', '');
            }
            if (args.contains('is-active')) {
              return ProcessResult(3, 0, 'active\n', '');
            }
            if (args.contains('show')) {
              return ProcessResult(4, 0, '3579\n', '');
            }
            return ProcessResult(0, 0, '', '');
          },
        );

        expect(calls, hasLength(4));
        expect(calls[0], ['systemctl', '--user', 'start', 'php8.2-fpm']);
        expect(calls[1], ['systemctl', 'start', 'php8.2-fpm']);
        expect(calls[2], ['systemctl', 'is-active', 'php8.2-fpm']);
        expect(calls[3], [
          'systemctl',
          'show',
          '--property=MainPID',
          '--value',
          'php8.2-fpm',
        ]);

        expect(app.serviceStatus, 'running');
        expect(app.servicePid, 3579);
        expect(statusChanged, isTrue);
        expect(manager.isRunning(app.appId), isTrue);
      },
    );

    test(
      'Case 3: Both user and system service fail -> throws Exception and serviceStatus is stopped',
      () async {
        final calls = <List<String>>[];
        final manager = AppServiceManager(AppLogger);
        final app = createPhpApp();

        await expectLater(
          manager.startPhpFpmViaSystemctlForTesting(
            app,
            isLinux: true,
            runProcess: (exec, args) async {
              calls.add([exec, ...args]);
              if (args.contains('--user')) {
                return ProcessResult(1, 1, '', 'User service unit not found');
              }
              return ProcessResult(2, 1, '', 'System service unit not found');
            },
          ),
          throwsA(isA<Exception>()),
        );

        expect(calls, hasLength(2));
        expect(calls[0], ['systemctl', '--user', 'start', 'php8.2-fpm']);
        expect(calls[1], ['systemctl', 'start', 'php8.2-fpm']);
        expect(app.serviceStatus, 'stopped');
        expect(manager.isRunning(app.appId), isFalse);
      },
    );

    test(
      'Case 4: Start succeeds but probe is-active returns failed -> treated as failure, reverts to stopped',
      () async {
        final calls = <List<String>>[];
        final manager = AppServiceManager(AppLogger);
        final app = createPhpApp();

        await expectLater(
          manager.startPhpFpmViaSystemctlForTesting(
            app,
            isLinux: true,
            runProcess: (exec, args) async {
              calls.add([exec, ...args]);
              if (args.contains('start')) {
                return ProcessResult(1, 0, '', '');
              }
              if (args.contains('is-active')) {
                return ProcessResult(2, 3, 'failed\n', 'Service crashed');
              }
              return ProcessResult(0, 0, '', '');
            },
          ),
          throwsA(
            predicate(
              (e) =>
                  e is Exception &&
                  e.toString().contains('failed liveness probe'),
            ),
          ),
        );

        expect(calls, hasLength(2));
        expect(calls[0], ['systemctl', '--user', 'start', 'php8.2-fpm']);
        expect(calls[1], ['systemctl', '--user', 'is-active', 'php8.2-fpm']);
        expect(app.serviceStatus, 'stopped');
        expect(app.servicePid, isNull);
        expect(manager.isRunning(app.appId), isFalse);
      },
    );

    test(
      'Case 5: Stop service invokes systemctl stop and resets state to stopped',
      () async {
        final calls = <List<String>>[];
        final manager = AppServiceManager(AppLogger);
        final app = createPhpApp();
        app.serviceStatus = 'running';
        app.servicePid = 4321;

        await manager.stopPhpFpmViaSystemctlForTesting(
          app,
          isLinux: true,
          runProcess: (exec, args) async {
            calls.add([exec, ...args]);
            if (args.contains('--user')) {
              return ProcessResult(1, 1, '', 'Not loaded in user session');
            }
            return ProcessResult(2, 0, '', '');
          },
        );

        expect(calls, hasLength(2));
        expect(calls[0], ['systemctl', '--user', 'stop', 'php8.2-fpm']);
        expect(calls[1], ['systemctl', 'stop', 'php8.2-fpm']);
        expect(app.serviceStatus, 'stopped');
        expect(app.servicePid, isNull);
        expect(manager.isRunning(app.appId), isFalse);
      },
    );

    test(
      'Case 6: On non-Linux (isLinux == false), throws Exception clearly when start is called',
      () async {
        final calls = <List<String>>[];
        final manager = AppServiceManager(AppLogger);
        final app = createPhpApp();

        await expectLater(
          manager.startPhpFpmViaSystemctlForTesting(
            app,
            isLinux: false,
            runProcess: (exec, args) async {
              calls.add([exec, ...args]);
              return ProcessResult(0, 0, '', '');
            },
          ),
          throwsA(
            predicate(
              (e) =>
                  e is Exception &&
                  e.toString().contains('systemctl is only available on Linux'),
            ),
          ),
        );

        expect(calls, isEmpty);
        expect(app.serviceStatus, 'stopped');
      },
    );

    test(
      'isPhpFpmRunningViaSystemctl queries active status correctly',
      () async {
        final manager = AppServiceManager(AppLogger);
        final app = createPhpApp();

        // 1. User service active -> returns true
        final res1 = await manager.isPhpFpmRunningViaSystemctl(
          app,
          isLinux: true,
          runProcess: (exec, args) async {
            if (args.contains('--user') && args.contains('is-active')) {
              return ProcessResult(1, 0, 'active\n', '');
            }
            return ProcessResult(2, 1, 'inactive\n', '');
          },
        );
        expect(res1, isTrue);

        // 2. System service active -> returns true
        final res2 = await manager.isPhpFpmRunningViaSystemctl(
          app,
          isLinux: true,
          runProcess: (exec, args) async {
            if (args.contains('--user') && args.contains('is-active')) {
              return ProcessResult(1, 1, 'inactive\n', '');
            }
            if (!args.contains('--user') && args.contains('is-active')) {
              return ProcessResult(2, 0, 'active\n', '');
            }
            return ProcessResult(3, 1, 'failed\n', '');
          },
        );
        expect(res2, isTrue);

        // 3. Both inactive -> returns false
        final res3 = await manager.isPhpFpmRunningViaSystemctl(
          app,
          isLinux: true,
          runProcess: (exec, args) async {
            return ProcessResult(1, 1, 'inactive\n', '');
          },
        );
        expect(res3, isFalse);

        // 4. Non-Linux -> returns false immediately
        final res4 = await manager.isPhpFpmRunningViaSystemctl(
          app,
          isLinux: false,
        );
        expect(res4, isFalse);
      },
    );

    test('User service start throws exception, falls back to system start', () async {
      final calls = <List<String>>[];
      final manager = AppServiceManager(AppLogger);
      final app = createPhpApp();

      await manager.startPhpFpmViaSystemctlForTesting(
        app,
        isLinux: true,
        runProcess: (exec, args) async {
          calls.add([exec, ...args]);
          if (args.contains('--user') && args.contains('start')) {
            throw ProcessException('systemctl', args, 'Bus error', 1);
          }
          if (!args.contains('--user') && args.contains('start')) {
            return ProcessResult(2, 0, '', '');
          }
          if (args.contains('is-active')) {
            return ProcessResult(3, 0, 'active\n', '');
          }
          if (args.contains('show')) {
            return ProcessResult(4, 0, '8888\n', '');
          }
          return ProcessResult(0, 0, '', '');
        },
      );

      expect(calls, hasLength(4));
      expect(calls[0], ['systemctl', '--user', 'start', 'php8.2-fpm']);
      expect(calls[1], ['systemctl', 'start', 'php8.2-fpm']);
      expect(calls[2], ['systemctl', 'is-active', 'php8.2-fpm']);
      expect(calls[3], [
        'systemctl',
        'show',
        '--property=MainPID',
        '--value',
        'php8.2-fpm',
      ]);
      expect(app.serviceStatus, 'running');
      expect(app.servicePid, 8888);
      expect(manager.isRunning(app.appId), isTrue);
    });

    test('phpFpmServiceName maps versions to correct systemd unit names', () {
      final manager = AppServiceManager(AppLogger);
      expect(manager.phpFpmServiceNameForTesting('php82'), 'php8.2-fpm');
      expect(manager.phpFpmServiceNameForTesting('php83'), 'php8.3-fpm');
      expect(manager.phpFpmServiceNameForTesting('php84'), 'php8.4-fpm');
      expect(manager.phpFpmServiceNameForTesting('php'), 'php-fpm');
    });
  });
}
