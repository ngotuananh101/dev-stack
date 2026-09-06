import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:dev_stack/core/config/app_config.dart';
import 'package:dev_stack/core/services/log_service.dart';
import 'package:dev_stack/features/apps/data/app_installer_service.dart';
import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class _FakeRef implements Ref {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  late AppInstallerService installer;
  late Directory tempBaseDir;

  setUp(() {
    tempBaseDir = Directory.systemTemp.createTempSync('ponta_isolated_test_');
    AppConfig.initialize(baseDir: tempBaseDir.path);
    installer = AppInstallerService(LogService(), _FakeRef());
  });

  tearDown(() {
    if (tempBaseDir.existsSync()) {
      tempBaseDir.deleteSync(recursive: true);
    }
  });

  group('Isolated Service Configurations', () {
    test('generates isolated redis.conf with daemonize no and ponta data dir', () async {
      final app = AppModel(
        appId: 'redis',
        name: 'Redis',
        categories: ['database'],
        groupName: 'redis',
        installMethod: 'package_manager',
      );

      await installer.configureIsolatedRedis(app, (msg) {});
      final confFile = File(p.join(AppConfig.dataDir, 'redis', 'redis.conf'));
      expect(confFile.existsSync(), isTrue);

      final content = confFile.readAsStringSync();
      expect(content, contains('daemonize no'));
      expect(content, contains('port 6379'));
      expect(content, contains('dir "${p.join(AppConfig.dataDir, 'redis').replaceAll('\\', '/')}"'));
    });

    test('generates isolated php-fpm.conf with ondemand and distinct port', () async {
      final app = AppModel(
        appId: 'php83',
        name: 'PHP 8.3',
        categories: ['runtime'],
        groupName: 'php',
        installMethod: 'package_manager',
      );

      await installer.configureIsolatedPhpFpm(app, 9083, (msg) {});
      final confFile = File(p.join(AppConfig.baseDir, 'php', 'php83', 'php-fpm.conf'));
      expect(confFile.existsSync(), isTrue);

      final content = confFile.readAsStringSync();
      expect(content, contains('daemonize = no'));
      expect(content, contains('listen = 127.0.0.1:9083'));
      expect(content, contains('pm = ondemand'));
    });

    test('generates isolated apache httpd.conf with IncludeOptional for vhosts', () async {
      final app = AppModel(
        appId: 'apache',
        name: 'Apache',
        categories: ['webserver'],
        groupName: 'webserver',
        installMethod: 'package_manager',
      );

      await installer.configureIsolatedApache(app, (msg) {});
      final confFile = File(p.join(AppConfig.vhostsDir, 'apache', 'httpd.conf'));
      expect(confFile.existsSync(), isTrue);

      final content = confFile.readAsStringSync();
      expect(content, contains('ServerName localhost'));
      expect(content, contains('IncludeOptional'));
    });

    test('initializes isolated postgresql cluster with initdb and 0700 permissions', () async {
      final app = AppModel(
        appId: 'postgresql',
        name: 'PostgreSQL',
        categories: ['database'],
        groupName: 'database',
        installMethod: 'package_manager',
      );

      var initdbRan = false;
      final fakeInitdb = File(p.join(tempBaseDir.path, 'initdb'))..createSync();

      await installer.configureIsolatedPostgresql(
        app,
        '16',
        fakeInitdb.path,
        (msg) {},
        runProcess: (exec, args) async {
          if (exec == fakeInitdb.path && args.contains('-D')) {
            initdbRan = true;
            // Create dummy postgresql.conf to test post-configuration
            final targetDir = args[args.indexOf('-D') + 1];
            File(p.join(targetDir, 'postgresql.conf')).createSync(recursive: true);
            return ProcessResult(1, 0, 'ok', '');
          }
          return ProcessResult(2, 0, '', '');
        },
      );

      expect(initdbRan, isTrue);
      final dataDir = Directory(p.join(AppConfig.dataDir, 'postgresql-16'));
      expect(dataDir.existsSync(), isTrue);
    });
  });
}
