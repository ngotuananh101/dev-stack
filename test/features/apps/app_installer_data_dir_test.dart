import 'dart:io';

import 'package:dev_stack/core/config/app_config.dart';
import 'package:dev_stack/core/services/log_service.dart';
import 'package:dev_stack/features/apps/data/app_installer_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempRoot;
  late AppInstallerService installer;
  final logs = <String>[];

  void logInfo(String m) => logs.add(m);

  setUp(() {
    tempRoot = Directory.systemTemp.createTempSync('ponta_datadir_test_');
    AppConfig.initialize(baseDir: tempRoot.path);
    installer = AppInstallerService(LogService(), _FakeRef());
    logs.clear();
    AppInstallerService.debugRenameFailure = null;
    AppInstallerService.debugCopyFailure = null;
  });

  tearDown(() {
    AppConfig.initialize(baseDir: AppConfig.defaultBaseDir);
    // Best-effort cleanup: LogService keeps a handle on its log file inside the
    // temp base dir, and Windows refuses to delete an open file.
    try {
      if (tempRoot.existsSync()) {
        tempRoot.deleteSync(recursive: true);
      }
    } on FileSystemException {
      // Leave it to the OS temp sweeper.
    }
  });

  /// Creates a populated data dir for [appId]-[version] and returns it.
  Directory seedDataDir(String appId, String version, String marker) {
    final dir = Directory(p.join(AppConfig.dataDir, '$appId-$version'))
      ..createSync(recursive: true);
    File(p.join(dir.path, 'user_table.ibd')).writeAsStringSync(marker);
    return dir;
  }

  /// Seeds a PostgreSQL data dir whose `PG_VERSION` records [major], so
  /// carry-over can detect a cross-major upgrade against the target version.
  Directory seedPostgresDataDir(String version, int major, String marker) {
    final dir = Directory(p.join(AppConfig.dataDir, 'postgresql-$version'))
      ..createSync(recursive: true);
    File(p.join(dir.path, 'PG_VERSION')).writeAsStringSync('$major\n');
    File(p.join(dir.path, 'postgresql.conf')).writeAsStringSync(marker);
    return dir;
  }

  group('hasVersionedDataDir', () {
    test('is true for database engines, false for others', () {
      expect(AppInstallerService.hasVersionedDataDir('mysql'), isTrue);
      expect(AppInstallerService.hasVersionedDataDir('mariadb'), isTrue);
      expect(AppInstallerService.hasVersionedDataDir('postgresql'), isTrue);
      expect(AppInstallerService.hasVersionedDataDir('nginx'), isFalse);
      expect(AppInstallerService.hasVersionedDataDir('php82'), isFalse);
    });
  });

  group('delete(deleteData:)', () {
    test('preserves the data directory during a version swap', () async {
      final data = seedDataDir('mysql', '8.0.36', 'my precious databases');
      final install = Directory(
        p.join(tempRoot.path, 'apps', 'mysql', '8.0.36'),
      )..createSync(recursive: true);

      await installer.delete(
        install.path,
        'mysql',
        '8.0.36',
        deleteData: false,
      );

      expect(install.existsSync(), isFalse, reason: 'install dir removed');
      expect(data.existsSync(), isTrue, reason: 'data MUST survive an update');
      expect(
        File(p.join(data.path, 'user_table.ibd')).readAsStringSync(),
        'my precious databases',
      );
    });

    test('removes the data directory on a real uninstall', () async {
      final data = seedDataDir('mysql', '8.0.36', 'gone');
      final install = Directory(
        p.join(tempRoot.path, 'apps', 'mysql', '8.0.36'),
      )..createSync(recursive: true);

      await installer.delete(install.path, 'mysql', '8.0.36');

      expect(install.existsSync(), isFalse);
      expect(data.existsSync(), isFalse, reason: 'uninstall clears data');
    });
  });

  group('carryOverDataDir', () {
    test('moves data from the old version key to the new one', () async {
      final old = seedDataDir('mysql', '8.0.36', 'production-like data');

      final carried = await installer.carryOverDataDir(
        'mysql',
        '8.0.36',
        '8.0.39',
        logInfo,
      );

      final newDir = Directory(p.join(AppConfig.dataDir, 'mysql-8.0.39'));
      expect(carried, isTrue);
      expect(old.existsSync(), isFalse);
      expect(newDir.existsSync(), isTrue);
      expect(
        File(p.join(newDir.path, 'user_table.ibd')).readAsStringSync(),
        'production-like data',
      );
    });

    test('restores the old version key when installation fails', () async {
      final old = seedDataDir('mysql', '8.0.36', 'recoverable data');

      final carried = await installer.carryOverDataDir(
        'mysql',
        '8.0.36',
        '8.0.39',
        logInfo,
      );
      expect(carried, isTrue);
      expect(old.existsSync(), isFalse);

      await installer.rollbackCarriedDataDir(
        'mysql',
        '8.0.36',
        '8.0.39',
        logInfo,
      );

      expect(old.existsSync(), isTrue);
      expect(
        File(p.join(old.path, 'user_table.ibd')).readAsStringSync(),
        'recoverable data',
      );
      expect(
        Directory(p.join(AppConfig.dataDir, 'mysql-8.0.39')).existsSync(),
        isFalse,
      );
    });

    test('does not clobber an existing non-empty destination', () async {
      seedDataDir('mysql', '8.0.36', 'old');
      final existingNew = seedDataDir('mysql', '8.0.39', 'already here');

      final carried = await installer.carryOverDataDir(
        'mysql',
        '8.0.36',
        '8.0.39',
        logInfo,
      );

      expect(carried, isFalse);
      expect(
        File(p.join(existingNew.path, 'user_table.ibd')).readAsStringSync(),
        'already here',
      );
    });

    test('is a no-op for apps without a versioned data dir', () async {
      final carried = await installer.carryOverDataDir(
        'nginx',
        '1.24.0',
        '1.25.0',
        logInfo,
      );
      expect(carried, isFalse);
    });

    test('is a no-op when there is no old data to carry', () async {
      final carried = await installer.carryOverDataDir(
        'mysql',
        '8.0.36',
        '8.0.39',
        logInfo,
      );
      expect(carried, isFalse);
    });

    test('is a no-op when the version is unchanged', () async {
      seedDataDir('mysql', '8.0.36', 'data');
      final carried = await installer.carryOverDataDir(
        'mysql',
        '8.0.36',
        '8.0.36',
        logInfo,
      );
      expect(carried, isFalse);
    });

    test('leaves no partial destination when the copy fails midway', () async {
      seedDataDir('mysql', '8.0.36', 'large database');
      AppInstallerService.debugRenameFailure = () =>
          throw const FileSystemException('Cross-device link');
      AppInstallerService.debugCopyFailure = () =>
          throw const FileSystemException('No space left on device');

      await expectLater(
        installer.carryOverDataDir('mysql', '8.0.36', '8.0.39', logInfo),
        throwsA(isA<FileSystemException>()),
        reason: 'the update must abort instead of running on partial data',
      );

      expect(
        Directory(p.join(AppConfig.dataDir, 'mysql-8.0.39')).existsSync(),
        isFalse,
        reason: 'a half-copied datadir would be adopted as live data',
      );
      expect(
        File(
          p.join(AppConfig.dataDir, 'mysql-8.0.36', 'user_table.ibd'),
        ).readAsStringSync(),
        'large database',
      );
    });
  });

  group('postgresql cross-major upgrade', () {
    test('does not carry data when the major version differs', () async {
      seedPostgresDataDir('15.17', 15, 'pg15 cluster config');

      final carried = await installer.carryOverDataDir(
        'postgresql',
        '15.17',
        '16.13',
        logInfo,
      );

      expect(carried, isFalse);
      expect(
        Directory(p.join(AppConfig.dataDir, 'postgresql-15.17')).existsSync(),
        isTrue,
        reason: 'the old major datadir must be left intact',
      );
      expect(
        File(
          p.join(AppConfig.dataDir, 'postgresql-15.17', 'PG_VERSION'),
        ).readAsStringSync().trim(),
        '15',
      );
      expect(
        Directory(p.join(AppConfig.dataDir, 'postgresql-16.13')).existsSync(),
        isFalse,
        reason:
            'no PG16 datadir should appear — initdb creates a fresh cluster',
      );
    });

    test('carries data when the major version is the same', () async {
      seedPostgresDataDir('16.3', 16, 'pg16 cluster config');

      final carried = await installer.carryOverDataDir(
        'postgresql',
        '16.3',
        '16.13',
        logInfo,
      );

      expect(carried, isTrue);
      expect(
        Directory(p.join(AppConfig.dataDir, 'postgresql-16.13')).existsSync(),
        isTrue,
      );
    });
  });

  test(
    'end-to-end: updating MySQL keeps the user databases reachable',
    () async {
      // User is on 8.0.36 with real data.
      seedDataDir('mysql', '8.0.36', 'customer records');
      final install36 = Directory(
        p.join(tempRoot.path, 'apps', 'mysql', '8.0.36'),
      )..createSync(recursive: true);

      // Update flow: carry data over, then remove the old install.
      await installer.carryOverDataDir('mysql', '8.0.36', '8.0.39', logInfo);
      await installer.delete(
        install36.path,
        'mysql',
        '8.0.36',
        deleteData: false,
      );

      // The engine on 8.0.39 resolves <dataDir>/mysql-8.0.39.
      final live = File(
        p.join(AppConfig.dataDir, 'mysql-8.0.39', 'user_table.ibd'),
      );
      expect(live.existsSync(), isTrue);
      expect(live.readAsStringSync(), 'customer records');
    },
  );
}

/// `carryOverDataDir` and `delete` never touch the Ref, so a stub is enough.
class _FakeRef implements Ref {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
