import 'dart:io';

import 'package:dev_stack/core/config/app_config.dart';
import 'package:dev_stack/core/services/log_service.dart';
import 'package:dev_stack/features/apps/data/app_installer_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../helpers/runtime_bundle_fixture.dart';
import '../../helpers/test_ref.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late Directory root;
  late AppInstallerService installer;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync(
      'installer_bundle_detection_test_',
    );
    root = createApacheBundleFixture(tempDir);
    AppConfig.initialize(baseDir: p.join(tempDir.path, 'app data'));
    installer = AppInstallerService(LogService(), testRef());
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('detects the bin/ launcher, never the libexec ELF', () async {
    final detected = await installer.detectFiles(
      root.path,
      'httpd',
      'httpd',
      (_) {},
    );
    expect(detected['exec'], p.join(root.path, 'bin', 'httpd'));
    expect(detected['cli'], p.join(root.path, 'bin', 'httpd'));

    File(p.join(root.path, 'bin', 'httpd')).deleteSync();
    final missing = await installer.detectFiles(
      root.path,
      'httpd',
      'httpd',
      (_) {},
    );
    expect(
      missing['exec'],
      isNull,
      reason: 'libexec/bin/httpd is not runnable directly',
    );
    expect(missing['cli'], isNull);
  });

  test(
    'PostgreSQL resolves launcher from manifest, non-manifest files via fallback',
    () async {
      final pgRoot = createPostgresqlBundleFixture(tempDir);
      final detected = await installer.detectFiles(
        pgRoot.path,
        'postgres',
        'psql',
        (_) {},
      );
      expect(detected['exec'], p.join(pgRoot.path, 'bin', 'postgres'));
      expect(detected['cli'], p.join(pgRoot.path, 'bin', 'psql'));

      File(p.join(pgRoot.path, 'bin', 'postgres')).deleteSync();
      final missing = await installer.detectFiles(
        pgRoot.path,
        'postgres',
        'psql',
        (_) {},
      );
      expect(
        missing['exec'],
        isNull,
        reason: 'libexec/bin/postgres is not runnable directly',
      );
      expect(missing['cli'], p.join(pgRoot.path, 'bin', 'psql'));
    },
  );

  test(
    'PostgreSQL non-manifest launcher detected when parent directory contains libexec',
    () async {
      final libexecParent = Directory(p.join(tempDir.path, 'libexec', 'nested'))
        ..createSync(recursive: true);
      final pgRoot = createPostgresqlBundleFixture(libexecParent);
      final detected = await installer.detectFiles(
        pgRoot.path,
        'postgres',
        'psql',
        (_) {},
      );
      expect(detected['exec'], p.join(pgRoot.path, 'bin', 'postgres'));
      expect(detected['cli'], p.join(pgRoot.path, 'bin', 'psql'));
    },
  );

  test(
    'manifest-less directory resolves both exec and cli via recursive listing',
    () async {
      final plainDir = Directory(p.join(tempDir.path, 'plain_archive'))
        ..createSync(recursive: true);
      Directory(p.join(plainDir.path, 'bin')).createSync();
      File(
        p.join(plainDir.path, 'bin', 'app'),
      ).writeAsStringSync('#!/bin/sh\nexit 0\n');
      final toolFile = File(p.join(plainDir.path, 'tool'))
        ..writeAsStringSync('#!/bin/sh\nexit 0\n');

      final detected = await installer.detectFiles(
        plainDir.path,
        'app',
        'tool',
        (_) {},
      );
      expect(detected['exec'], endsWith(p.join('bin', 'app')));
      expect(detected['cli'], toolFile.path);
    },
  );
}
