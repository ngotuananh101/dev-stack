import 'dart:io';

import 'package:dev_stack/features/apps/data/app_installer_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('AppInstallerService.configureSdkRuntime', () {
    late Directory tempDir;
    late List<String> envVars;
    late List<String> pathDirs;
    late List<String> logs;
    late List<(String, List<String>, bool)> commands;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('sdk_runtime_test_');
      envVars = [];
      pathDirs = [];
      logs = [];
      commands = [];
    });

    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    /// Creates `<install>/bin/<name>` so the wiring sees a complete SDK.
    String installWithLauncher(String name) {
      final bin = Directory(p.join(tempDir.path, 'bin'))
        ..createSync(recursive: true);
      File(p.join(bin.path, name)).writeAsStringSync('#!/bin/sh\n');
      return tempDir.path;
    }

    Future<void> configure(
      String appId,
      String installPath, {
      int exitCode = 0,
      bool isWindows = false,
      Object? error,
    }) {
      return AppInstallerService.configureSdkRuntime(
        appId: appId,
        installPath: installPath,
        isWindows: isWindows,
        logInfo: logs.add,
        setEnvVar: (name, value) async => envVars.add('$name=$value'),
        addPathDir: (dir) async => pathDirs.add(dir),
        run: (exe, args, {bool runInShell = false}) async {
          commands.add((exe, args, runInShell));
          if (error != null) throw error;
          return ProcessResult(1, exitCode, 'Flutter 3.47.9', '');
        },
      );
    }

    test('Go gets GOROOT and bin/ on PATH, and nothing runs', () async {
      await configure('go', installWithLauncher('go'));

      expect(envVars, ['GOROOT=${tempDir.path}']);
      expect(pathDirs, [p.join(tempDir.path, 'bin')]);
      expect(commands, isEmpty);
      expect(logs.any((l) => l.contains('go, gofmt')), isTrue);
    });

    test('Flutter gets bin/ on PATH and runs its launcher once', () async {
      final installPath = installWithLauncher('flutter');
      await configure('flutter', installPath);

      expect(envVars, isEmpty);
      expect(pathDirs, [p.join(installPath, 'bin')]);
      expect(commands, hasLength(1));
      expect(commands.single.$1, p.join(installPath, 'bin', 'flutter'));
      expect(commands.single.$2, ['--version']);
      expect(commands.single.$3, isFalse);
    });

    test('the Windows launcher runs through cmd', () async {
      final installPath = installWithLauncher('flutter.bat');

      await configure('flutter', installPath, isWindows: true);

      expect(commands.single.$3, isTrue);
    });

    test('Java gets JAVA_HOME, bin/ on PATH, and a version check', () async {
      final installPath = installWithLauncher('java');
      await configure('java', installPath);

      expect(envVars, ['JAVA_HOME=$installPath']);
      expect(pathDirs, [p.join(installPath, 'bin')]);
      expect(commands, hasLength(1));
      expect(commands.single.$1, p.join(installPath, 'bin', 'java'));
      expect(commands.single.$2, ['-version']);
    });

    test('the JDK is checked through java.exe, not a guessed .bat', () async {
      final installPath = installWithLauncher('java.exe');

      await configure('java', installPath, isWindows: true);

      expect(
        commands.single.$1,
        p.join(installPath, 'bin', 'java.exe'),
        reason: 'a guessed java.bat would report a complete install as broken',
      );
      expect(commands.single.$3, isTrue);
      expect(logs.any((l) => l.contains('missing')), isFalse);
    });

    test('a missing launcher is reported without running anything', () async {
      await configure('flutter', tempDir.path);

      expect(commands, isEmpty);
      expect(
        logs.any((l) => l.contains('missing')),
        isTrue,
        reason: 'an incomplete extraction must be visible in the log',
      );
    });

    test('a failed launcher run leaves PATH wired', () async {
      final installPath = installWithLauncher('flutter');

      await configure('flutter', installPath, exitCode: 1);

      expect(pathDirs, [p.join(installPath, 'bin')]);
      expect(logs.any((l) => l.toLowerCase().contains('warning')), isTrue);
    });

    test('a launcher that cannot start is logged, not thrown', () async {
      final installPath = installWithLauncher('flutter');

      await configure(
        'flutter',
        installPath,
        error: const ProcessException('flutter', []),
      );

      expect(pathDirs, [p.join(installPath, 'bin')]);
      expect(logs.any((l) => l.contains('could not')), isTrue);
    });

    test('other runtimes are untouched', () async {
      await configure('nodejs', tempDir.path);
      await configure('php84', tempDir.path);

      expect(envVars, isEmpty);
      expect(pathDirs, isEmpty);
      expect(commands, isEmpty);
    });
  });
}
