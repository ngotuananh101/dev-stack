import 'dart:io';
import 'dart:isolate';

import 'package:dev_stack/features/apps/data/app_installer_service.dart';
import 'package:dev_stack/features/apps/data/runtime_sdk_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// End-to-end check of the JDK install path against a real Temurin archive:
/// extract it with the built-in decoder, flatten the `jdk-*` wrapper the way
/// the installer does, then start the VM through the launcher the wiring
/// picks. Ignored unless JAVA_SDK_ARCHIVE points at a downloaded archive.
///
/// The JDK is the one runtime whose archive layout differs from Go's and
/// Flutter's in a way that matters: `bin/java` is a real ELF binary whose
/// `lib/server/libjvm.so` sits outside `bin/`, so a half-extracted archive
/// still has a `bin/java` and only the version check catches it.
void main() {
  final archive = Platform.environment['JAVA_SDK_ARCHIVE'];
  final skip = archive == null ? 'set JAVA_SDK_ARCHIVE to run' : null;
  // JDK 8 reports `1.8.0_504` while every later line reports its own dotted
  // version, so the expected string is a parameter rather than a constant.
  final expected = Platform.environment['JAVA_SDK_EXPECT'] ?? '21.0.13';

  test('installs a real JDK archive and starts the VM', () async {
    final root = Directory.systemTemp.createTempSync('java_e2e_');
    addTearDown(() => root.deleteSync(recursive: true));
    final installPath = p.join(root.path, 'java', expected);
    Directory(installPath).createSync(recursive: true);

    // 1. Extract exactly the way the installer does.
    final summary = await Isolate.run(
      () => AppInstallerService.extractArchiveToDirectory(
        archive!,
        installPath,
      ),
    );
    // A JDK is a few hundred files, not the tens of thousands Go and Flutter
    // carry: since JDK 9 the runtime is modularized into `lib/modules` rather
    // than a tree of class files.
    expect(summary.fileCount, greaterThan(300));
    expect(summary.skippedEntries, isEmpty);

    // 2. The archive has one top-level directory, named after the release
    //    (`jdk-21.0.13+9`), which the installer lifts its contents out of.
    final top = Directory(installPath).listSync();
    expect(top, hasLength(1));
    expect(p.basename(top.single.path), startsWith('jdk'));
    for (final entity in Directory(top.single.path).listSync()) {
      entity.renameSync(p.join(installPath, p.basename(entity.path)));
    }

    // 3. Every tool the catalog advertises must be there.
    final config = RuntimeSdkConfig.forApp('java', installPath)!;
    expect(config.envVars['JAVA_HOME'], installPath);
    expect(config.pathDirs, [p.join(installPath, 'bin')]);
    expect(config.shims, ['java', 'javac', 'jar']);
    for (final shim in config.shims) {
      expect(
        File(p.join(installPath, 'bin', shim)).existsSync(),
        isTrue,
        reason: 'bin/$shim is advertised but missing',
      );
    }

    // 4. Run the version check the post-install step runs. `java -version`
    //    writes to stderr, so the assertion reads both streams.
    final launcher = p.join(
      installPath,
      'bin',
      RuntimeSdkConfig.launcherFile('java', isWindows: false)!,
    );
    final warmup = RuntimeSdkConfig.warmupCommand(
      'java',
      launcher,
      isWindows: false,
    );
    expect(warmup, isNotNull);

    final version = await Process.run(
      warmup!.executable,
      warmup.arguments,
      runInShell: warmup.runInShell,
      environment: {
        'JAVA_HOME': installPath,
        'PATH': Platform.environment['PATH'] ?? '',
      },
    );
    expect(version.exitCode, 0, reason: '${version.stderr}');
    expect('${version.stdout}${version.stderr}', contains(expected));

    // 5. The compiler shares that JVM; if `javac` starts, the SDK is whole.
    final javac = await Process.run(
      p.join(installPath, 'bin', 'javac'),
      ['-version'],
      environment: {
        'JAVA_HOME': installPath,
        'PATH': Platform.environment['PATH'] ?? '',
      },
    );
    expect(javac.exitCode, 0, reason: '${javac.stderr}');
    expect('${javac.stdout}${javac.stderr}', contains(expected));
  }, skip: skip, timeout: const Timeout(Duration(minutes: 15)));
}
