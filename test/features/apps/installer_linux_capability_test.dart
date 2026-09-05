import 'dart:io';

import 'package:dev_stack/core/config/app_config.dart';
import 'package:dev_stack/core/services/log_service.dart';
import 'package:dev_stack/features/apps/data/app_installer_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

class _FakeRef implements Ref {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  late AppInstallerService installerService;
  late Directory tempAppsDir;

  setUp(() {
    installerService = AppInstallerService(LogService(), _FakeRef());
    tempAppsDir = Directory.systemTemp.createTempSync('ponta_test_apps_');
    AppConfig.initialize(baseDir: tempAppsDir.path);
  });

  tearDown(() {
    if (tempAppsDir.existsSync()) {
      tempAppsDir.deleteSync(recursive: true);
    }
  });

  group('Linux Capability Setup for Webservers', () {
    test('skips capability setup on non-Linux platforms', () async {
      final logMessages = <String>[];
      final dummyBinary = File(p.join(AppConfig.appsDir, 'caddy'))..createSync(recursive: true);

      var processCalled = false;
      await installerService.setLinuxCapabilityForWebserver(
        dummyBinary.path,
        logMessages.add,
        isLinuxOverride: false,
        runProcess: (executable, arguments) async {
          processCalled = true;
          return ProcessResult(1234, 0, '', '');
        },
      );

      expect(processCalled, isFalse);
      expect(logMessages, isEmpty);
    });

    test('skips executable outside appsDir for security', () async {
      final logMessages = <String>[];
      const outsidePath = '/usr/bin/evil_tool';

      var processCalled = false;
      await installerService.setLinuxCapabilityForWebserver(
        outsidePath,
        logMessages.add,
        isLinuxOverride: true,
        runProcess: (executable, arguments) async {
          processCalled = true;
          return ProcessResult(1234, 0, '', '');
        },
      );

      expect(processCalled, isFalse);
      expect(logMessages.any((msg) => msg.contains('outside')), isTrue);
    });

    test('skips non-existent executable gracefully', () async {
      final logMessages = <String>[];
      final nonExistentPath = p.join(AppConfig.appsDir, 'nginx');

      var processCalled = false;
      await installerService.setLinuxCapabilityForWebserver(
        nonExistentPath,
        logMessages.add,
        isLinuxOverride: true,
        runProcess: (executable, arguments) async {
          processCalled = true;
          return ProcessResult(1234, 0, '', '');
        },
      );

      expect(processCalled, isFalse);
      expect(logMessages.any((msg) => msg.contains('Executable not found')), isTrue);
    });

    test('calls sudo setcap successfully on valid binary', () async {
      final logMessages = <String>[];
      final nginxBinary = File(p.join(AppConfig.appsDir, 'nginx'))..createSync(recursive: true);

      final executedCommands = <String>[];
      final executedArgs = <List<String>>[];

      await installerService.setLinuxCapabilityForWebserver(
        nginxBinary.path,
        logMessages.add,
        isLinuxOverride: true,
        runProcess: (executable, arguments) async {
          executedCommands.add(executable);
          executedArgs.add(arguments);
          return ProcessResult(1234, 0, '', '');
        },
      );

      expect(executedCommands, equals(['sudo']));
      expect(executedArgs.first, equals(['setcap', 'cap_net_bind_service=+ep', nginxBinary.path]));
      expect(logMessages.any((msg) => msg.contains('Successfully set capability')), isTrue);
    });

    test('falls back to pkexec when sudo fails', () async {
      final logMessages = <String>[];
      final caddyBinary = File(p.join(AppConfig.appsDir, 'caddy'))..createSync(recursive: true);

      final executedCommands = <String>[];

      await installerService.setLinuxCapabilityForWebserver(
        caddyBinary.path,
        logMessages.add,
        isLinuxOverride: true,
        runProcess: (executable, arguments) async {
          executedCommands.add(executable);
          if (executable == 'sudo') {
            return ProcessResult(1234, 1, '', 'sudo: not found');
          }
          return ProcessResult(1234, 0, '', '');
        },
      );

      expect(executedCommands, equals(['sudo', 'pkexec']));
      expect(logMessages.any((msg) => msg.contains('Sudo failed, trying pkexec')), isTrue);
      expect(logMessages.any((msg) => msg.contains('Successfully set capability via pkexec')), isTrue);
    });

    test('logs manual guidance when both sudo and pkexec fail', () async {
      final logMessages = <String>[];
      final apacheBinary = File(p.join(AppConfig.appsDir, 'httpd'))..createSync(recursive: true);

      await installerService.setLinuxCapabilityForWebserver(
        apacheBinary.path,
        logMessages.add,
        isLinuxOverride: true,
        runProcess: (executable, arguments) async {
          return ProcessResult(1234, 1, '', '');
        },
      );

      expect(logMessages.any((msg) => msg.contains('Could not set capability')), isTrue);
      expect(logMessages.any((msg) => msg.contains('sudo setcap cap_net_bind_service=+ep')), isTrue);
      expect(logMessages.any((msg) => msg.contains('ports >= 1024')), isTrue);
    });
  });
}
