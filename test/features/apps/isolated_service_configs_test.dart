import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:dev_stack/core/config/apache_config_builder.dart';
import 'package:dev_stack/core/config/app_config.dart';
import 'package:dev_stack/core/services/log_service.dart';
import 'package:dev_stack/features/apps/data/app_installer_service.dart';
import 'package:dev_stack/features/apps/domain/app_model.dart';
import '../../helpers/runtime_bundle_fixture.dart';
import '../../helpers/test_ref.dart';

RegExp _apacheGlobToRegExp(String glob) {
  var pattern = glob;
  pattern = pattern.replaceAllMapped(
    RegExp(r'\[!(.*?)\]'),
    (m) => '[^${m[1]}]',
  );
  pattern = pattern.replaceAll('.', r'\.');
  pattern = pattern.replaceAll('*', '.*');
  pattern = pattern.replaceAll('?', '.');
  return RegExp('^$pattern\$');
}


void main() {
  late AppInstallerService installer;
  late Directory tempBaseDir;

  setUp(() {
    tempBaseDir = Directory.systemTemp.createTempSync('ponta_isolated_test_');
    AppConfig.initialize(baseDir: tempBaseDir.path);
    installer = AppInstallerService(LogService(), testRef());
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
      );

      await installer.configureIsolatedPhpFpm(app, 9083, (msg) {});
      final confFile = File(p.join(AppConfig.baseDir, 'php', 'php83', 'php-fpm.conf'));
      expect(confFile.existsSync(), isTrue);

      final content = confFile.readAsStringSync();
      expect(content, contains('daemonize = no'));
      expect(content, contains('listen = 127.0.0.1:9083'));
      expect(content, contains('pm = ondemand'));
    });

    test('generates isolated apache _httpd.conf from bundle with [a-zA-Z0-9]*.conf and mod_unixd', () async {
      final bundleDir = createApacheBundleFixture(tempBaseDir);
      final app = AppModel(
        appId: 'apache',
        name: 'Apache',
        categories: ['webserver'],
        groupName: 'webserver',
      );

      await installer.configureApacheBundle(app, bundleDir.path, (msg) {});
      final confFile = File(
        p.join(AppConfig.vhostsDir, 'apache', ApacheConfigBuilder.mainConfigFileName),
      );
      expect(confFile.existsSync(), isTrue);

      final oldConfFile = File(p.join(AppConfig.vhostsDir, 'apache', 'httpd.conf'));
      expect(oldConfFile.existsSync(), isFalse);

      final content = confFile.readAsStringSync();
      expect(
        content,
        contains(
          'IncludeOptional "${p.join(AppConfig.vhostsDir, 'apache', ApacheConfigBuilder.vhostsGlobPattern).replaceAll('\\', '/')}"',
        ),
      );
      expect(content, contains('LoadModule unixd_module modules/mod_unixd.so'));
    });

    test('IncludeOptional glob matches hello.test.conf alongside main config while excluding _httpd.conf', () async {
      final bundleDir = createApacheBundleFixture(tempBaseDir);
      final app = AppModel(
        appId: 'apache',
        name: 'Apache',
        categories: ['webserver'],
        groupName: 'webserver',
      );

      await installer.configureApacheBundle(app, bundleDir.path, (msg) {});
      final confFile = File(
        p.join(AppConfig.vhostsDir, 'apache', ApacheConfigBuilder.mainConfigFileName),
      );
      expect(confFile.existsSync(), isTrue);

      final helloConf = File(p.join(AppConfig.vhostsDir, 'apache', 'hello.test.conf'))
        ..writeAsStringSync('# hello.test vhost');
      expect(helloConf.existsSync(), isTrue);

      final content = confFile.readAsStringSync();
      final match = RegExp(r'IncludeOptional\s+"([^"]+)"').firstMatch(content);
      expect(match, isNotNull);
      final globPath = match!.group(1)!;
      final globFileName = p.posix.basename(globPath);

      final regex = _apacheGlobToRegExp(globFileName);

      // Must match hello.test.conf
      expect(
        regex.hasMatch(p.basename(helloConf.path)),
        isTrue,
        reason: 'Sites starting with "h" must not be excluded by the include glob',
      );
      // Must NOT match _httpd.conf
      expect(
        regex.hasMatch(p.basename(confFile.path)),
        isFalse,
        reason: 'The main config file must not match its own include glob',
      );
    });

    test('initializes isolated postgresql cluster with initdb and 0700 permissions', () async {
      final app = AppModel(
        appId: 'postgresql',
        name: 'PostgreSQL',
        categories: ['database'],
        groupName: 'database',
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

    test('configures unix_socket_directories = /tmp on Linux during init', () async {
      final app = AppModel(
        appId: 'postgresql',
        name: 'PostgreSQL',
        categories: ['database'],
        groupName: 'database',
      );

      final fakeInitdb = File(p.join(tempBaseDir.path, 'initdb2'))..createSync();

      await installer.configureIsolatedPostgresql(
        app,
        '17',
        fakeInitdb.path,
        (msg) {},
        isLinux: true,
        runProcess: (exec, args) async {
          if (exec == fakeInitdb.path && args.contains('-D')) {
            final targetDir = args[args.indexOf('-D') + 1];
            File(p.join(targetDir, 'postgresql.conf')).writeAsStringSync(
              "#unix_socket_directories = '/var/run/postgresql'\nlisten_addresses = 'localhost'\n",
            );
            return ProcessResult(1, 0, 'ok', '');
          }
          return ProcessResult(2, 0, '', '');
        },
      );

      final confFile = File(p.join(AppConfig.dataDir, 'postgresql-17', 'postgresql.conf'));
      expect(confFile.existsSync(), isTrue);
      final content = confFile.readAsStringSync();
      expect(content, contains("unix_socket_directories = '/tmp'"));
      expect(content, contains("listen_addresses = '127.0.0.1'"));
    });

    test('binds listen_addresses to * when allowLanAccess is true', () async {
      final app = AppModel(
        appId: 'postgresql',
        name: 'PostgreSQL',
        categories: ['database'],
        groupName: 'database',
      );

      final fakeInitdb = File(p.join(tempBaseDir.path, 'initdb3'))..createSync();

      await installer.configureIsolatedPostgresql(
        app,
        '18',
        fakeInitdb.path,
        (msg) {},
        isLinux: true,
        allowLanAccess: true,
        runProcess: (exec, args) async {
          if (exec == fakeInitdb.path && args.contains('-D')) {
            final targetDir = args[args.indexOf('-D') + 1];
            File(p.join(targetDir, 'postgresql.conf')).writeAsStringSync(
              "listen_addresses = 'localhost'\n",
            );
            return ProcessResult(1, 0, 'ok', '');
          }
          return ProcessResult(2, 0, '', '');
        },
      );

      final confFile = File(p.join(AppConfig.dataDir, 'postgresql-18', 'postgresql.conf'));
      expect(confFile.existsSync(), isTrue);
      final content = confFile.readAsStringSync();
      expect(content, contains("listen_addresses = '*'"));
    });

    test('cleans up temp password dir when runner throws ProcessException', () async {
      final app = AppModel(
        appId: 'postgresql',
        name: 'PostgreSQL',
        categories: ['database'],
        groupName: 'database',
      );

      final fakeInitdb = File(p.join(tempBaseDir.path, 'initdb_throw'))..createSync();

      final existingTempDirs = Directory.systemTemp
          .listSync()
          .whereType<Directory>()
          .map((d) => d.path)
          .where((name) => p.basename(name).startsWith('ponta-pg-pw-'))
          .toSet();

      String? capturedPwFilePath;

      await expectLater(
        installer.configureIsolatedPostgresql(
          app,
          '19',
          fakeInitdb.path,
          (msg) {},
          isLinux: true,
          runProcess: (exec, args) async {
            if (args.contains('--pwfile')) {
              capturedPwFilePath = args[args.indexOf('--pwfile') + 1];
            }
            throw const ProcessException('initdb', ['-D'], 'Permission denied', 13);
          },
        ),
        throwsA(isA<ProcessException>()),
      );

      expect(capturedPwFilePath, isNotNull);
      final pwDir = Directory(p.dirname(capturedPwFilePath!));
      expect(pwDir.existsSync(), isFalse);

      final remainingTempDirs = Directory.systemTemp
          .listSync()
          .whereType<Directory>()
          .map((d) => d.path)
          .where((name) => p.basename(name).startsWith('ponta-pg-pw-'))
          .toSet();

      final newDirs = remainingTempDirs.difference(existingTempDirs);
      expect(newDirs, isEmpty);
    });

    test('reports stdout and stderr with exit code on initdb failure', () async {
      final app = AppModel(
        appId: 'postgresql',
        name: 'PostgreSQL',
        categories: ['database'],
        groupName: 'database',
      );

      final fakeInitdb = File(p.join(tempBaseDir.path, 'initdb_fail'))..createSync();
      final logs = <String>[];

      await expectLater(
        installer.configureIsolatedPostgresql(
          app,
          '20',
          fakeInitdb.path,
          logs.add,
          isLinux: true,
          runProcess: (exec, args) async {
            if (exec == fakeInitdb.path) {
              return ProcessResult(
                1234,
                42,
                'initdb: distinctive standard output',
                'initdb: fatal error occurred',
              );
            }
            return ProcessResult(2, 0, '', '');
          },
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            allOf(
              contains('(exit code 42)'),
              contains('initdb: fatal error occurred'),
            ),
          ),
        ),
      );

      expect(
        logs,
        contains('initdb stdout: initdb: distinctive standard output'),
      );
      expect(
        logs,
        contains('initdb stderr: initdb: fatal error occurred'),
      );
    });

    test('ensurePostgresUnixSocketDirectory adds or replaces socket directory', () {
      const commented = "#unix_socket_directories = '/var/run/postgresql'\nport = 5432\n";
      final updated = AppInstallerService.ensurePostgresUnixSocketDirectory(commented);
      expect(updated, contains("unix_socket_directories = '/tmp'"));
      expect(updated, isNot(contains('/var/run/postgresql')));

      const missing = "port = 5432\n";
      final added = AppInstallerService.ensurePostgresUnixSocketDirectory(missing);
      expect(added, contains("unix_socket_directories = '/tmp'"));
    });
  });
}
