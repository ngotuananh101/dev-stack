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
  late Directory tempDir;

  setUp(() {
    installerService = AppInstallerService(LogService(), _FakeRef());
    tempDir = Directory.systemTemp.createTempSync('ponta_perm_test_');
    AppConfig.initialize(baseDir: tempDir.path);
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('AppInstallerService.ensureLinuxExecutablePermissions', () {
    test('skips permission update on non-Linux platforms', () async {
      final dummyFile = File(p.join(tempDir.path, 'bun'))..createSync();
      var processCalled = false;
      final logs = <String>[];

      await AppInstallerService.ensureLinuxExecutablePermissions(
        dummyFile.path,
        isLinuxOverride: false,
        logInfo: logs.add,
        runProcess: (exec, args) async {
          processCalled = true;
          return ProcessResult(1234, 0, '', '');
        },
      );

      expect(processCalled, isFalse);
      expect(logs, isEmpty);
    });

    test('logs warning when file does not exist', () async {
      final nonExistentPath = p.join(tempDir.path, 'non_existent_binary');
      var processCalled = false;
      final logs = <String>[];

      await AppInstallerService.ensureLinuxExecutablePermissions(
        nonExistentPath,
        isLinuxOverride: true,
        logInfo: logs.add,
        runProcess: (exec, args) async {
          processCalled = true;
          return ProcessResult(1234, 0, '', '');
        },
      );

      expect(processCalled, isFalse);
      expect(logs.any((msg) => msg.contains('File not found')), isTrue);
    });

    test('calls chmod u+x on valid binary file on Linux', () async {
      final dummyFile = File(p.join(tempDir.path, 'deno'))..createSync();
      final executed = <List<String>>[];
      final logs = <String>[];

      await AppInstallerService.ensureLinuxExecutablePermissions(
        dummyFile.path,
        isLinuxOverride: true,
        logInfo: logs.add,
        runProcess: (exec, args) async {
          executed.add([exec, ...args]);
          return ProcessResult(1234, 0, '', '');
        },
      );

      expect(executed, hasLength(1));
      expect(executed.first, ['chmod', 'u+x', dummyFile.path]);
      expect(logs.any((msg) => msg.contains('Ensured executable permission')), isTrue);
    });

    test('logs warning if chmod u+x returns non-zero exit code', () async {
      final dummyFile = File(p.join(tempDir.path, 'meilisearch'))..createSync();
      final logs = <String>[];

      await AppInstallerService.ensureLinuxExecutablePermissions(
        dummyFile.path,
        isLinuxOverride: true,
        logInfo: logs.add,
        runProcess: (exec, args) async {
          return ProcessResult(1234, 1, '', 'Permission denied');
        },
      );

      expect(logs.any((msg) => msg.contains('chmod u+x failed')), isTrue);
    });

    test('catches exceptions during chmod gracefully', () async {
      final dummyFile = File(p.join(tempDir.path, 'nginx'))..createSync();
      final logs = <String>[];

      await expectLater(
        AppInstallerService.ensureLinuxExecutablePermissions(
          dummyFile.path,
          isLinuxOverride: true,
          logInfo: logs.add,
          runProcess: (exec, args) async {
            throw ProcessException('chmod', ['u+x', dummyFile.path], 'error', 1);
          },
        ),
        completes,
      );

      expect(logs.any((msg) => msg.contains('Could not set executable permission')), isTrue);
    });
  });

  group('AppInstallerService.detectFiles Linux permission integration', () {
    test('enforces chmod u+x on detected exec and cli paths on Linux', () async {
      final binDir = Directory(p.join(tempDir.path, 'bin'))..createSync(recursive: true);
      final execFile = File(p.join(binDir.path, 'nginx'))..createSync();
      final cliFile = File(p.join(binDir.path, 'nginx-cli'))..createSync();

      final executed = <List<String>>[];
      final logs = <String>[];

      final result = await installerService.detectFiles(
        tempDir.path,
        'nginx',
        'nginx-cli',
        logs.add,
        isLinuxOverride: true,
        runProcess: (exec, args) async {
          executed.add([exec, ...args]);
          return ProcessResult(1234, 0, '', '');
        },
      );

      expect(result['exec'], equals(execFile.path));
      expect(result['cli'], equals(cliFile.path));
      expect(executed, hasLength(2));
      expect(executed[0], ['chmod', 'u+x', execFile.path]);
      expect(executed[1], ['chmod', 'u+x', cliFile.path]);
    });

    test('skips chmod u+x when isLinuxOverride is false', () async {
      final binDir = Directory(p.join(tempDir.path, 'bin'))..createSync(recursive: true);
      final execFile = File(p.join(binDir.path, 'nginx'))..createSync();

      final executed = <List<String>>[];
      final logs = <String>[];

      final result = await installerService.detectFiles(
        tempDir.path,
        'nginx',
        null,
        logs.add,
        isLinuxOverride: false,
        runProcess: (exec, args) async {
          executed.add([exec, ...args]);
          return ProcessResult(1234, 0, '', '');
        },
      );

      expect(result['exec'], equals(execFile.path));
      expect(executed, isEmpty);
    });
  });
}
