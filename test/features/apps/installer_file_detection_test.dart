import 'dart:io';

import 'package:dev_stack/core/config/app_config.dart';
import 'package:dev_stack/core/services/log_service.dart';
import 'package:dev_stack/features/apps/data/app_installer_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../helpers/test_ref.dart';

void main() {
  group('AppInstallerService.isPreferredCandidate', () {
    const root = '/opt/ponta/apps/flutter/3.47.9';

    test('prefers the SDK launcher over a copy nested deeper', () {
      // Flutter ships both: bin/dart is the launcher that bootstraps the SDK,
      // bin/cache/dart-sdk/bin/dart is the bundled binary it installs.
      expect(
        AppInstallerService.isPreferredCandidate(
          '$root/bin/dart',
          '$root/bin/cache/dart-sdk/bin/dart',
          root,
        ),
        isTrue,
      );
    });

    test('keeps the first match when depths are equal', () {
      expect(
        AppInstallerService.isPreferredCandidate(
          '$root/a/go',
          '$root/b/go',
          root,
        ),
        isFalse,
      );
    });

    test('does not replace a shallower match with a deeper one', () {
      expect(
        AppInstallerService.isPreferredCandidate(
          '$root/lib/bin/go',
          '$root/bin/go',
          root,
        ),
        isFalse,
      );
    });
  });

  group('AppInstallerService.detectFiles', () {
    late Directory tempDir;
    late AppInstallerService installer;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync(
        'installer_file_detection_test_',
      );
      AppConfig.initialize(baseDir: p.join(tempDir.path, 'app data'));
      installer = AppInstallerService(LogService(), testRef());
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test(
      'recursive scan selects shallowest exec and cli candidates across the full tree',
      () async {
        final root = Directory(p.join(tempDir.path, 'sdk'))..createSync();

        final deepExec = File(p.join(root.path, 'lib', 'nested', 'bin', 'tool'))
          ..createSync(recursive: true);
        await deepExec.writeAsString('');
        final shallowExec = File(p.join(root.path, 'bin', 'tool'))
          ..createSync(recursive: true);
        await shallowExec.writeAsString('');

        final deepCli = File(p.join(root.path, 'opt', 'extra', 'cli-tool'))
          ..createSync(recursive: true);
        await deepCli.writeAsString('');
        final shallowCli = File(p.join(root.path, 'cli-tool'))
          ..createSync(recursive: true);
        await shallowCli.writeAsString('');

        final detected = await installer.detectFiles(
          root.path,
          'tool',
          'cli-tool',
          (_) {},
          isLinuxOverride: false,
        );

        expect(detected['exec'], shallowExec.path);
        expect(detected['cli'], shallowCli.path);
      },
    );
  });
}
