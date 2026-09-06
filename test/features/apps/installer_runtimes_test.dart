import 'dart:io';
import 'package:dev_stack/features/apps/data/app_installer_service.dart';
import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('AppInstallerService runtime post-configuration', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('installer_runtime_test_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('configureBunBinary creates bunx.exe when bun.exe exists', () async {
      final bunExe = File(p.join(tempDir.path, 'bun.exe'));
      await bunExe.writeAsString('mock bun binary');

      final bunxExe = File(p.join(tempDir.path, 'bunx.exe'));
      expect(bunxExe.existsSync(), isFalse);

      await AppInstallerService.configureBunBinary(
        installPath: tempDir.path,
        isWindows: true,
        logInfo: (_) {},
      );

      expect(bunxExe.existsSync(), isTrue);
      expect(await bunxExe.readAsString(), equals('mock bun binary'));
    });

    test('configureBunBinary is a no-op when not on Windows', () async {
      final bunExe = File(p.join(tempDir.path, 'bun'));
      await bunExe.writeAsString('mock bun binary');

      await AppInstallerService.configureBunBinary(
        installPath: tempDir.path,
        isWindows: false,
        logInfo: (_) {},
      );

      final bunx = File(p.join(tempDir.path, 'bunx'));
      expect(bunx.existsSync(), isFalse);
    });
  });
}
