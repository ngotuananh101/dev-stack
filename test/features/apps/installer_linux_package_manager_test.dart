import 'dart:io';

import 'package:dev_stack/features/apps/data/app_installer_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildPackageManagerScript', () {
    test('generates a POSIX script with fail-closed set -e and non-interactive flags', () {
      final script = AppInstallerService.buildPackageManagerScript([
        'sudo apt-get update',
        'sudo apt-get install -y php8.5-fpm',
      ]);

      expect(script, contains('#!/bin/sh'));
      expect(script, contains('set -e'));
      expect(script, contains('export DEBIAN_FRONTEND=noninteractive'));
      expect(script, contains('export NEEDRESTART_MODE=a'));
      expect(script, contains('sudo() { "\$@"; }'));
      expect(script, contains('sudo apt-get update'));
      expect(script, contains('sudo apt-get install -y php8.5-fpm'));
    });

    test('escapes quotes in echo notices safely', () {
      final script = AppInstallerService.buildPackageManagerScript([
        'echo "deb [signed-by=/key.gpg] https://repo main" | sudo tee /etc/apt/sources.list.d/test.list',
      ]);

      expect(script, contains("[0/1] Running:"));
      expect(script, contains('sudo tee /etc/apt/sources.list.d/test.list'));
    });
  });

  group('executePackageManagerCommands', () {
    test('uses non-interactive sudo when sudo -n true succeeds', () async {
      final logInfoMsgs = <String>[];
      final logErrorMsgs = <String>[];
      final executedCalls = <({String exec, List<String> args})>[];

      final result = await AppInstallerService.executePackageManagerCommands(
        commands: ['apt-get update'],
        logInfo: logInfoMsgs.add,
        logError: logErrorMsgs.add,
        isLinuxOverride: true,
        runProcess: (exec, args) async {
          executedCalls.add((exec: exec, args: args));
          if (exec == 'sudo' && args.first == '-n') {
            return ProcessResult(1, 0, '', '');
          }
          if (exec == 'chmod') {
            return ProcessResult(2, 0, '', '');
          }
          if (exec == 'sudo' && args.first == 'sh') {
            return ProcessResult(3, 0, 'Success output', '');
          }
          return ProcessResult(4, 1, '', 'unexpected');
        },
      );

      expect(result.exitCode, equals(0));
      expect(logInfoMsgs.any((m) => m.contains('via sudo (non-interactive)')), isTrue);
      expect(executedCalls.any((c) => c.exec == 'sudo' && c.args.first == 'sh'), isTrue);
      expect(executedCalls.any((c) => c.exec == 'pkexec'), isFalse);
    });

    test('falls back to pkexec elevation when sudo requires a password', () async {
      final logInfoMsgs = <String>[];
      final logErrorMsgs = <String>[];
      final executedCalls = <({String exec, List<String> args})>[];

      final result = await AppInstallerService.executePackageManagerCommands(
        commands: ['apt-get update'],
        logInfo: logInfoMsgs.add,
        logError: logErrorMsgs.add,
        isLinuxOverride: true,
        runProcess: (exec, args) async {
          executedCalls.add((exec: exec, args: args));
          if (exec == 'sudo' && args.first == '-n') {
            // Sudo requires password
            return ProcessResult(1, 1, '', 'sudo: a password is required');
          }
          if (exec == 'chmod') {
            return ProcessResult(2, 0, '', '');
          }
          if (exec == 'pkexec') {
            return ProcessResult(3, 0, 'Installed successfully', '');
          }
          return ProcessResult(4, 1, '', 'unexpected');
        },
      );

      expect(result.exitCode, equals(0));
      expect(logInfoMsgs.any((m) => m.contains('via pkexec')), isTrue);
      expect(executedCalls.any((c) => c.exec == 'pkexec' && c.args.first == 'sh'), isTrue);
    });

    test('throws cancellation exception when user dismisses pkexec authentication', () async {
      final logInfoMsgs = <String>[];
      final logErrorMsgs = <String>[];

      await expectLater(
        AppInstallerService.executePackageManagerCommands(
          commands: ['apt-get update'],
          logInfo: logInfoMsgs.add,
          logError: logErrorMsgs.add,
          isLinuxOverride: true,
          runProcess: (exec, args) async {
            if (exec == 'sudo' && args.first == '-n') {
              return ProcessResult(1, 1, '', 'sudo: a password is required');
            }
            if (exec == 'chmod') {
              return ProcessResult(2, 0, '', '');
            }
            if (exec == 'pkexec') {
              // Standard Polkit dismissal exit code is 126
              return ProcessResult(3, 126, '', 'Error executing command as another user: Request dismissed');
            }
            return ProcessResult(4, 1, '', 'unexpected');
          },
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('authentication was cancelled'),
          ),
        ),
      );

      expect(logErrorMsgs.any((m) => m.contains('cancelled')), isTrue);
    });

    test('throws installation failure with stderr on script failure', () async {
      final logInfoMsgs = <String>[];
      final logErrorMsgs = <String>[];

      await expectLater(
        AppInstallerService.executePackageManagerCommands(
          commands: ['apt-get update'],
          logInfo: logInfoMsgs.add,
          logError: logErrorMsgs.add,
          isLinuxOverride: true,
          runProcess: (exec, args) async {
            if (exec == 'sudo' && args.first == '-n') {
              return ProcessResult(1, 0, '', '');
            }
            if (exec == 'chmod') {
              return ProcessResult(2, 0, '', '');
            }
            if (exec == 'sudo' && args.first == 'sh') {
              return ProcessResult(3, 100, '', 'E: Unable to locate package');
            }
            return ProcessResult(4, 1, '', 'unexpected');
          },
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Unable to locate package'),
          ),
        ),
      );

      expect(logErrorMsgs.any((m) => m.contains('Command failed with exit code 100')), isTrue);
    });
  });
}
