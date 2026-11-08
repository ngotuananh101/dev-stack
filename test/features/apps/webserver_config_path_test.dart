import 'dart:io';

import 'package:dev_stack/core/config/app_config.dart';
import 'package:dev_stack/features/apps/data/webserver_settings_provider.dart';
import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('resolves Caddyfile at the Caddy install root', () {
    final app = AppModel(
      appId: 'caddy',
      name: 'Caddy',
      categories: const ['webserver'],
      groupName: 'webserver',
      location: r'C:\Ponta\apps\caddy\2.11.4',
    );

    expect(
      webserverConfigFileFor(app)?.path,
      p.join(r'C:\Ponta\apps\caddy\2.11.4', 'Caddyfile'),
    );
  });

  group('Apache config path on Linux', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync(
        'webserver_config_path_test_',
      );
      AppConfig.initialize(baseDir: tempDir.path);
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('prefers isolated <vhosts>/apache/httpd.conf when it exists', () {
      final isolatedDir = Directory(p.join(AppConfig.vhostsDir, 'apache'))
        ..createSync(recursive: true);
      final isolatedConf = File(p.join(isolatedDir.path, 'httpd.conf'))
        ..writeAsStringSync('isolated');

      final app = AppModel(
        appId: 'apache',
        name: 'Apache',
        categories: const ['webserver'],
        groupName: 'webserver',
        location: p.join(tempDir.path, 'bundle'),
      );

      final resolved = webserverConfigFileFor(app, isLinux: true);
      expect(resolved?.path, isolatedConf.path);
    });

    test(
      'falls back to bundle conf/httpd.conf when isolated config does not exist',
      () {
        final app = AppModel(
          appId: 'apache',
          name: 'Apache',
          categories: const ['webserver'],
          groupName: 'webserver',
          location: p.join(tempDir.path, 'bundle'),
        );

        final resolved = webserverConfigFileFor(app, isLinux: true);
        expect(
          resolved?.path,
          p.join(tempDir.path, 'bundle', 'conf', 'httpd.conf'),
        );
      },
    );
  });
}
