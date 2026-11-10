import 'dart:io';
import 'dart:isolate';

import 'package:dev_stack/features/apps/data/app_installer_service.dart';
import 'package:dev_stack/features/apps/data/runtime_sdk_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// End-to-end check of the Go install path against a real go.dev archive:
/// stream the tarball to disk, extract it with the built-in decoder, flatten
/// like the installer does, detect the files, then wire and start the
/// toolchain. Ignored unless GO_SDK_ARCHIVE points at a downloaded archive.
void main() {
  final archive = Platform.environment['GO_SDK_ARCHIVE'];
  final skip = archive == null ? 'set GO_SDK_ARCHIVE to run' : null;

  test('installs a real Go archive and starts the toolchain', () async {
    final root = Directory.systemTemp.createTempSync('go_e2e_');
    addTearDown(() => root.deleteSync(recursive: true));
    final installPath = p.join(root.path, 'go', '1.27.3');
    Directory(installPath).createSync(recursive: true);

    // 1. Extract exactly the way _installFromTar does.
    final summary = await Isolate.run(
      () => AppInstallerService.extractArchiveToDirectory(
        archive!,
        installPath,
      ),
    );
    expect(summary.fileCount, greaterThan(10000));
    expect(summary.skippedEntries, isEmpty);

    // 2. _flattenDirectory removes the single top-level `go/` wrapper.
    final top = Directory(installPath).listSync();
    expect(top, hasLength(1));
    expect(p.basename(top.single.path), 'go');
    for (final entity in Directory(top.single.path).listSync()) {
      entity.renameSync(p.join(installPath, p.basename(entity.path)));
    }

    // 3. Both tools the catalog advertises must be there.
    expect(File(p.join(installPath, 'bin', 'go')).existsSync(), isTrue);
    expect(File(p.join(installPath, 'bin', 'gofmt')).existsSync(), isTrue);

    // 4. Run the real toolchain with the GOROOT the wiring would set.
    final version = await Process.run(
      p.join(installPath, 'bin', 'go'),
      ['version'],
      environment: {'GOROOT': installPath},
    );
    expect(version.exitCode, 0, reason: '${version.stderr}');
    expect(version.stdout, contains('go1.27.3'));

    final config = RuntimeSdkConfig.forApp('go', installPath)!;
    expect(config.envVars['GOROOT'], installPath);
    expect(config.pathDirs, [p.join(installPath, 'bin')]);
    expect(config.shims, ['go', 'gofmt']);
  }, skip: skip, timeout: const Timeout(Duration(minutes: 15)));
}
