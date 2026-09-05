import 'dart:io';

import 'package:dev_stack/core/services/background_process.dart';
import 'package:dev_stack/features/hosts/data/hosts_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HostsRepository security hardening (VULN-07)', () {
    test(
      'sets 0600 permissions on temporary hosts file on Linux before elevated copy',
      () async {
        final repo = HostsRepository();
        final executedCommands = <({String exec, List<String> args})>[];
        String? capturedTempFilePath;

        final result = await repo.saveHostsRaw(
          '127.0.0.1 test.local\n',
          isLinux: true,
          skipDirectWrite: true,
          runProcess: (exec, args) async {
            executedCommands.add((exec: exec, args: args));
            if (exec == 'chmod' && args.isNotEmpty && args[0] == '600') {
              capturedTempFilePath = args[1];
            }
            return ProcessResult(100, 0, '', '');
          },
        );

        expect(result, isTrue);
        expect(executedCommands, hasLength(2));

        // Command 1 must be chmod 600 <tempFile>
        expect(executedCommands[0].exec, equals('chmod'));
        expect(executedCommands[0].args, equals(['600', capturedTempFilePath]));

        // Command 2 must be pkexec cp <tempFile> /etc/hosts
        expect(executedCommands[1].exec, equals('pkexec'));
        expect(
          executedCommands[1].args,
          equals(['cp', capturedTempFilePath, '/etc/hosts']),
        );
      },
    );

    test(
      'cleans up temporary directory in finally block even when elevated copy fails',
      () async {
        final repo = HostsRepository();
        String? capturedTempDirPath;

        final result = await repo.saveHostsRaw(
          '127.0.0.1 failed.local\n',
          isLinux: true,
          skipDirectWrite: true,
          runProcess: (exec, args) async {
            if (exec == 'chmod' && args.length >= 2) {
              capturedTempDirPath = File(args[1]).parent.path;
            }
            if (exec == 'pkexec') {
              return ProcessResult(101, 1, '', 'Permission denied');
            }
            return ProcessResult(100, 0, '', '');
          },
        );

        expect(result, isFalse);
        expect(capturedTempDirPath, isNotNull);
        expect(Directory(capturedTempDirPath!).existsSync(), isFalse);
      },
    );

    test(
      'cleans up temporary directory when elevated copy succeeds',
      () async {
        final repo = HostsRepository();
        String? capturedTempDirPath;

        final result = await repo.saveHostsRaw(
          '127.0.0.1 success.local\n',
          isLinux: true,
          skipDirectWrite: true,
          runProcess: (exec, args) async {
            if (exec == 'chmod' && args.length >= 2) {
              capturedTempDirPath = File(args[1]).parent.path;
            }
            return ProcessResult(102, 0, '', '');
          },
        );

        expect(result, isTrue);
        expect(capturedTempDirPath, isNotNull);
        expect(Directory(capturedTempDirPath!).existsSync(), isFalse);
      },
    );
  });

  group('BackgroundProcess.runElevated audit logging (VULN-05)', () {
    test(
      'logs audit message with executable and arguments before executing pkexec on Linux',
      () async {
        final auditLogs = <String>[];
        String? executedExec;
        List<String>? executedArgs;

        final result = await BackgroundProcess.runElevated(
          'cp',
          ['/tmp/ponta_hosts_test/hosts', '/etc/hosts'],
          isLinux: true,
          logInfo: (msg) => auditLogs.add(msg),
          runProcess: (exec, args) async {
            executedExec = exec;
            executedArgs = args;
            return ProcessResult(200, 0, 'success', '');
          },
        );

        expect(result.exitCode, equals(0));
        expect(executedExec, equals('pkexec'));
        expect(
          executedArgs,
          equals(['cp', '/tmp/ponta_hosts_test/hosts', '/etc/hosts']),
        );

        expect(auditLogs, hasLength(1));
        expect(
          auditLogs.first,
          equals(
            'Audit: executing elevated command with pkexec: cp /tmp/ponta_hosts_test/hosts /etc/hosts',
          ),
        );
      },
    );

    test(
      'logs audit message when arguments are empty',
      () async {
        final auditLogs = <String>[];

        await BackgroundProcess.runElevated(
          'whoami',
          [],
          isLinux: true,
          logInfo: (msg) => auditLogs.add(msg),
          runProcess: (exec, args) async {
            return ProcessResult(201, 0, 'root', '');
          },
        );

        expect(auditLogs, hasLength(1));
        expect(
          auditLogs.first,
          equals('Audit: executing elevated command with pkexec: whoami'),
        );
      },
    );
  });
}
