import 'dart:io';

import 'package:dev_stack/features/apps/data/php_config_command_runner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PhpConfigCommandRunner', () {
    for (final command in [
      'apt-get install -y php8.5-curl',
      'apt-cache search php8.5-',
      'dnf repoquery php-*',
      'pacman -Fl php-gd',
      "sed -i 's,.*,owned,' /etc/shadow",
      "echo 'auto_prepend_file=/tmp/evil' | tee /etc/php.d/99-ponta-redis.ini",
      "echo 'extension=redis' | tee /etc/apt/sources.list.d/php.list",
      'phpenmod -v 8.5 -s fpm curl &',
    ]) {
      test('rejects $command before any process or elevation', () async {
        final calls = <String>[];
        await expectLater(
          PhpConfigCommandRunner(
            runProcess: (exe, args) async {
              calls.add([exe, ...args].join(' '));
              return ProcessResult(0, 0, '', '');
            },
          ).run(
            commands: ['phpenmod -v 8.5 -s fpm curl', command],
            logInfo: (_) {},
            logError: (_) {},
          ),
          throwsA(isA<StateError>()),
        );
        expect(calls, isEmpty);
      });
    }

    test('rejects an empty batch without requesting authorization', () async {
      var calls = 0;
      final runner = PhpConfigCommandRunner(
        runProcess: (_, args) async {
          calls++;
          return ProcessResult(0, 0, '', '');
        },
      );
      await expectLater(
        runner.run(commands: [], logInfo: (_) {}, logError: (_) {}),
        throwsA(isA<StateError>()),
      );
      expect(calls, 0);
    });

    test(
      'executes only validated PHP configuration in a fail-fast script',
      () async {
        final calls = <String>[];
        String? scriptPath;
        String? script;
        final runner = PhpConfigCommandRunner(
          runProcess: (exe, args) async {
            calls.add(exe);
            expect(exe, 'pkexec');
            expect(args.first, '/bin/sh');
            scriptPath = args[1];
            script = await File(scriptPath!).readAsString();
            return ProcessResult(42, 0, 'configured', '');
          },
        );
        final logs = <String>[];
        final result = await runner.run(
          commands: [
            'phpenmod -v 8.5 -s fpm curl',
            'phpdismod -v 8.5 -s fpm redis',
          ],
          logInfo: logs.add,
          logError: (_) {},
        );
        expect(result.exitCode, 0);
        expect(calls, ['pkexec']);
        expect(
          script,
          '#!/bin/sh\nset -e\nPATH=/usr/sbin:/usr/bin:/sbin:/bin\nexport PATH\n'
          'phpenmod -v 8.5 -s fpm curl\nphpdismod -v 8.5 -s fpm redis\n',
        );
        expect(logs.join('\n'), contains('configured'));
        expect(File(scriptPath!).existsSync(), isFalse);
      },
    );

    test(
      'propagates nonzero execution failures and cleans up its script',
      () async {
        String? scriptPath;
        final runner = PhpConfigCommandRunner(
          runProcess: (exe, args) async {
            scriptPath = args[1];
            return ProcessResult(42, 7, '', 'permission denied');
          },
        );
        final errors = <String>[];
        await expectLater(
          runner.run(
            commands: ['phpenmod -v 8.5 -s fpm curl'],
            logInfo: (_) {},
            logError: errors.add,
          ),
          throwsA(
            isA<ProcessException>()
                .having((e) => e.errorCode, 'exit code', 7)
                .having(
                  (e) => e.message,
                  'stderr',
                  contains('permission denied'),
                ),
          ),
        );
        expect(errors.join('\n'), contains('permission denied'));
        expect(File(scriptPath!).existsSync(), isFalse);
      },
    );

    test('propagates authorization cancellation', () async {
      final runner = PhpConfigCommandRunner(
        runProcess: (_, args) async =>
            ProcessResult(42, 126, '', 'not authorized'),
      );
      await expectLater(
        runner.run(
          commands: ['phpdismod -v 8.5 -s fpm curl'],
          logInfo: (_) {},
          logError: (_) {},
        ),
        throwsA(
          isA<ProcessException>().having((e) => e.errorCode, 'cancelled', 126),
        ),
      );
    });

    test('propagates process exceptions and cleans up its script', () async {
      String? scriptPath;
      const failure = ProcessException('pkexec', [], 'missing executable');
      final runner = PhpConfigCommandRunner(
        runProcess: (_, args) async {
          scriptPath = args[1];
          throw failure;
        },
      );
      await expectLater(
        runner.run(
          commands: ['phpdismod -v 8.5 -s fpm curl'],
          logInfo: (_) {},
          logError: (_) {},
        ),
        throwsA(same(failure)),
      );
      expect(File(scriptPath!).existsSync(), isFalse);
    });
  });
}
