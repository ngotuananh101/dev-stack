import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dev_stack/features/apps/data/apps_repository.dart';

void main() {
  Future<List<Map<String, dynamic>>> loadApps() async {
    final data = jsonDecode(
      await File('assets/data/apps-linux.json').readAsString(),
    );
    return (data['apps'] as List).cast<Map<String, dynamic>>();
  }

  test(
    'Linux catalog contains only archive definitions and HTTPS downloads',
    () async {
      final apps = await loadApps();
      expect(
        apps.map((a) => a['id']),
        containsAll([
          'nodejs',
          'caddy',
          'mysql',
          'pyenv',
          'apache',
          'redis',
          'postgresql',
        ]),
      );
      for (final app in apps) {
        expect(app['name'], isNotEmpty);
        expect(app['install_method'], isNot('package_manager'));
        expect(app.containsKey('package_manager_commands'), isFalse);
        expect(app['versions'], isA<Map>());
        for (final entry in (app['versions'] as Map).entries) {
          expect(entry.key, isNotEmpty);
          expect(entry.value, startsWith('https://'));
        }
        for (final key in ['exec_file', 'cli_file']) {
          final name = app[key] as String?;
          if (name != null) {
            expect(name.endsWith('.exe') || name.endsWith('.bat'), isFalse);
          }
        }
      }
    },
  );

  test('PHP archive definitions use unversioned bundle launchers', () async {
    final apps = await loadApps();
    final php = apps.where((a) => a['group_name'] == 'php');
    expect(php.length, 4);
    for (final app in php) {
      expect(app['exec_file'], 'php-fpm');
      expect(app['cli_file'], 'php');
      for (final url in (app['versions'] as Map).values) {
        expect(
          url,
          startsWith(
            'https://github.com/ngotuananh101/devstack-app-builder/releases/download/',
          ),
        );
        expect(
          url,
          matches(
            r'php-\d+\.\d+\.\d+-musl-dynamic-x86_64-[a-f0-9]{16}\.tar\.gz$',
          ),
        );
      }
    }
  });

  test('builder runtimes are installable from musl bundles', () async {
    final apps = await loadApps();
    for (final id in ['apache', 'php84', 'postgresql', 'redis']) {
      final app = apps.firstWhere((a) => a['id'] == id);
      expect(app['versions'], isNotEmpty, reason: '$id must be installable');
      for (final url in (app['versions'] as Map).values) {
        expect(
          url,
          startsWith(
            'https://github.com/ngotuananh101/devstack-app-builder/releases/download/',
          ),
        );
      }
    }
    final postgresql = apps.firstWhere((a) => a['id'] == 'postgresql');
    for (final url in (postgresql['versions'] as Map).values) {
      expect(
        url,
        matches(
          r'postgresql-\d+(?:\.\d+)+-musl-dynamic-x86_64-[a-f0-9]{16}\.tar\.gz$',
        ),
      );
    }
  });

  test('nginx still points at Jirutka static binaries', () async {
    final nginx = (await loadApps()).firstWhere((a) => a['id'] == 'nginx');
    expect(nginx['versions'], isNotEmpty);
    for (final url in (nginx['versions'] as Map).values) {
      expect(
        url,
        startsWith('https://jirutka.github.io/nginx-binaries/nginx-'),
      );
      expect(url, contains('-x86_64-linux'));
    }
  });

  test('catalog filenames remain platform-specific', () {
    expect(AppsRepository.catalogFileNameFor(isLinux: true), 'apps-linux.json');
    expect(AppsRepository.catalogFileNameFor(isLinux: false), 'apps.json');
  });
}
