import 'dart:io';
import 'dart:isolate';

import 'package:dev_stack/features/apps/data/app_installer_service.dart';
import 'package:dev_stack/features/apps/data/runtime_sdk_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// End-to-end check of the Flutter install path against a real archive:
/// stream the .tar.xz to disk, extract it with the built-in decoder (the
/// launcher it contains is the risky part — two `dart` files, two symlinks,
/// and scripts that must keep their executable bit), flatten, detect, then
/// run the real launcher. Ignored unless FLUTTER_SDK_ARCHIVE is set.
void main() {
  final archive = Platform.environment['FLUTTER_SDK_ARCHIVE'];
  final skip = archive == null ? 'set FLUTTER_SDK_ARCHIVE to run' : null;

  test('installs a real Flutter archive and runs the launcher', () async {
    final root = Directory.systemTemp.createTempSync('flutter_e2e_');
    addTearDown(() => root.deleteSync(recursive: true));
    final installPath = p.join(root.path, 'flutter', '3.47.9');
    Directory(installPath).createSync(recursive: true);

    // 1. Extract exactly the way _installFromTar does.
    final summary = await Isolate.run(
      () => AppInstallerService.extractArchiveToDirectory(
        archive!,
        installPath,
      ),
    );
    expect(summary.fileCount, greaterThan(15000));
    expect(summary.skippedEntries, isEmpty);

    // 2. _flattenDirectory removes the single top-level `flutter/` wrapper.
    final top = Directory(installPath).listSync();
    expect(top, hasLength(1));
    expect(p.basename(top.single.path), 'flutter');
    for (final entity in Directory(top.single.path).listSync()) {
      entity.renameSync(p.join(installPath, p.basename(entity.path)));
    }

    // 3. The launcher must survive extraction as an executable script, not a
    //    copy-content file: Flutter ships `bin/flutter` with mode 0755.
    final launcher = File(p.join(installPath, 'bin', 'flutter'));
    expect(launcher.existsSync(), isTrue);
    expect(launcher.readAsStringSync().startsWith('#!'), isTrue);
    expect(await _isExecutable(launcher.path), isTrue);

    // 4. Run it the way the post-install check does.
    final warmup = RuntimeSdkConfig.warmupCommand(
      'flutter',
      launcher.path,
      isWindows: false,
    );
    expect(warmup, isNotNull);

    final version = await Process.run(
      warmup!.executable,
      warmup.arguments,
      runInShell: warmup.runInShell,
      environment: {'HOME': root.path, 'PATH': Platform.environment['PATH'] ?? ''},
    );
    expect(version.exitCode, 0, reason: '${version.stderr}');
    expect(version.stdout.toString(), contains('3.47.9'));

    // 5. The bundled Dart SDK answers too, since the catalog advertises it.
    final dart = await Process.run(
      p.join(installPath, 'bin', 'dart'),
      ['--version'],
      environment: {'HOME': root.path, 'PATH': Platform.environment['PATH'] ?? ''},
    );
    expect(dart.exitCode, 0, reason: '${dart.stderr}');
  }, skip: skip, timeout: const Timeout(Duration(minutes: 20)));
}

Future<bool> _isExecutable(String path) async {
  final result = await Process.run('test', ['-x', path]);
  return result.exitCode == 0;
}
