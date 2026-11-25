import 'dart:io';

import 'package:dev_stack/core/config/app_config.dart';
import 'package:dev_stack/core/services/log_service.dart';
import 'package:dev_stack/features/apps/data/app_service_manager.dart';
import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  late String previousBaseDir;
  late LogService logger;
  late AppServiceManager manager;

  setUp(() {
    root = Directory.systemTemp.createTempSync('service_directories_');
    previousBaseDir = AppConfig.baseDir;
    AppConfig.initialize(baseDir: p.join(root.path, 'app data'));
    logger = LogService(logDir: p.join(root.path, 'test logs'));
    manager = AppServiceManager(logger, platformIsLinux: () => false);
  });

  tearDown(() async {
    await manager.dispose();
    await logger.info('Test finished');
    await AppLogger.info('Test finished');
    AppConfig.initialize(baseDir: previousBaseDir);
    root.deleteSync(recursive: true);
  });

  Future<AppModel> attemptStart(String executable) async {
    final file = File(p.join(root.path, 'installation', executable));
    file.parent.createSync(recursive: true);
    // An invalid, non-executable file prevents any real service from starting.
    file.writeAsStringSync('not an executable');
    final app = AppModel(
      appId: p.basenameWithoutExtension(executable),
      name: executable,
      categories: const ['webserver'],
      isInstalled: true,
      execFilePath: file.path,
    );
    await expectLater(manager.start(app), throwsA(isA<Exception>()));
    return app;
  }

  void writeVhost(String server, String name) {
    final file = File(p.join(AppConfig.vhostsDir, server, name));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync('# Existing user configuration\n');
  }

  for (final entry in {
    'nginx': 'nginx',
    'NGINX.EXE': 'nginx',
    'caddy': 'caddy',
    'caddy.exe': 'caddy',
    'httpd': 'apache',
    'apache2': 'apache',
    'httpd.exe': 'apache',
  }.entries) {
    test(
      '${entry.key} recreates managed directories before spawning',
      () async {
        writeVhost(entry.value, 'api.example.test.conf');

        final app = await attemptStart(entry.key);

        for (final directory in [
          AppConfig.webserverRoot,
          p.join(AppConfig.logsDir, 'localhost'),
          p.join(AppConfig.logsDir, 'api.example.test'),
          p.join(AppConfig.vhostsDir, entry.value, 'integrations'),
        ]) {
          expect(Directory(directory).existsSync(), isTrue, reason: directory);
        }
        expect(app.serviceStatus, 'stopped');
      },
    );
  }

  test('Nginx recreates its prefix logs and temporary directories', () async {
    await attemptStart('nginx');

    for (final directory in ['logs', 'temp']) {
      expect(
        Directory(p.join(root.path, 'installation', directory)).existsSync(),
        isTrue,
        reason: directory,
      );
    }
  });

  test(
    'each start repairs directories removed after a previous attempt',
    () async {
      writeVhost('nginx', 'api.example.test.conf');
      await attemptStart('nginx');
      final logs = Directory(p.join(AppConfig.logsDir, 'api.example.test'));
      expect(logs.existsSync(), isTrue);
      logs.deleteSync(recursive: true);
      Directory(
        p.join(root.path, 'installation', 'temp'),
      ).deleteSync(recursive: true);

      await attemptStart('nginx');

      expect(logs.existsSync(), isTrue);
      expect(
        Directory(p.join(root.path, 'installation', 'temp')).existsSync(),
        isTrue,
      );
    },
  );

  test('preparation preserves existing config and log contents', () async {
    writeVhost('nginx', 'api.example.test.conf');
    final config = File(
      p.join(AppConfig.vhostsDir, 'nginx', 'api.example.test.conf'),
    );
    final log = File(
      p.join(AppConfig.logsDir, 'api.example.test', 'nginx_access.log'),
    );
    log.parent.createSync(recursive: true);
    log.writeAsStringSync('existing access log\n');

    await attemptStart('nginx');
    await attemptStart('nginx');

    expect(config.readAsStringSync(), '# Existing user configuration\n');
    expect(log.readAsStringSync(), 'existing access log\n');
  });

  test('only site configs produce site log directories', () async {
    writeVhost('apache', 'api.example.test.conf');
    writeVhost('apache', '_httpd.conf');
    writeVhost('apache', 'notes.txt');
    writeVhost('apache', 'integrations/phpmyadmin.conf');
    Directory(
      p.join(AppConfig.vhostsDir, 'apache', 'directory.conf'),
    ).createSync();

    await attemptStart('httpd');

    expect(
      Directory(p.join(AppConfig.logsDir, 'api.example.test')).existsSync(),
      isTrue,
    );
    for (final name in ['_httpd', 'notes', 'phpmyadmin', 'directory']) {
      expect(
        Directory(p.join(AppConfig.logsDir, name)).existsSync(),
        isFalse,
        reason: name,
      );
    }
  });

  test(
    'Apache does not create runtime directories beside its executable',
    () async {
      writeVhost('apache', 'api.example.test.conf');

      await attemptStart('httpd');

      expect(
        Directory(p.join(AppConfig.logsDir, 'api.example.test')).existsSync(),
        isTrue,
      );
      expect(
        Directory(p.join(root.path, 'installation', 'logs')).existsSync(),
        isFalse,
      );
    },
  );

  test(
    'a file blocking a runtime directory fails before process creation',
    () async {
      final blocker = File(p.join(root.path, 'installation', 'temp'));
      blocker.parent.createSync(recursive: true);
      blocker.writeAsStringSync('keep this file');
      final executable = File(p.join(root.path, 'installation', 'nginx'))
        ..writeAsStringSync('not an executable');
      final app = AppModel(
        appId: 'nginx',
        name: 'Nginx',
        categories: const ['webserver'],
        execFilePath: executable.path,
      );

      await expectLater(
        manager.start(app),
        throwsA(isA<FileSystemException>()),
      );

      expect(app.serviceStatus, 'stopped');
      expect(blocker.readAsStringSync(), 'keep this file');
      expect(manager.isRunning(app.appId), isFalse);
    },
  );

  test('database starts do not recreate missing data directories', () async {
    await attemptStart('postgres');

    expect(Directory(AppConfig.dataDir).existsSync(), isFalse);
    expect(Directory(AppConfig.webserverRoot).existsSync(), isFalse);
    expect(Directory(AppConfig.vhostsDir).existsSync(), isFalse);
  });
}
