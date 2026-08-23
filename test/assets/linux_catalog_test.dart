import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dev_stack/features/apps/data/apps_repository.dart';

void main() {
  group('Linux App Catalog (apps-linux.json)', () {
    Future<List<Map<String, dynamic>>> loadApps() async {
      final raw = await File('assets/data/apps-linux.json').readAsString();
      return ((jsonDecode(raw) as Map<String, dynamic>)['apps'] as List)
          .cast<Map<String, dynamic>>();
    }

    test('apps-linux.json exists and parses as valid JSON', () async {
      final file = File('assets/data/apps-linux.json');
      expect(await file.exists(), isTrue, reason: 'assets/data/apps-linux.json should exist');

      final raw = await file.readAsString();
      final data = jsonDecode(raw);
      expect(data, isA<Map<String, dynamic>>());
      expect(data['apps'], isA<List>());
      expect(data['apps'], isNotEmpty);
    });

    test('contains essential apps with Linux configurations and download URLs', () async {
      final file = File('assets/data/apps-linux.json');
      final raw = await file.readAsString();
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final apps = (data['apps'] as List).cast<Map<String, dynamic>>();

      final appIds = apps.map((a) => a['id'] as String).toSet();
      final essentialIds = [
        'nodejs',
        'caddy',
        'mysql',
        'pyenv',
      ];

      for (final essentialId in essentialIds) {
        expect(appIds.contains(essentialId), isTrue,
            reason: 'Catalog should contain app: $essentialId');
      }

      // Check each app has valid properties
      for (final app in apps) {
        final id = app['id'] as String;
        expect(id, isNotEmpty, reason: 'App ID should not be empty');
        expect(app['name'], isA<String>(), reason: 'App $id should have a name');
        expect((app['name'] as String).isNotEmpty, isTrue);

        expect(app['versions'], isA<Map<String, dynamic>>(),
            reason: 'App $id should have versions map');
        final versions = app['versions'] as Map<String, dynamic>;
        expect(versions, isNotEmpty, reason: 'App $id should have at least one version');

        for (final entry in versions.entries) {
          expect(entry.key, isNotEmpty, reason: 'Version key in $id should not be empty');
          expect(entry.value, isA<String>(),
              reason: 'Version ${entry.key} URL in $id must be string');
          expect((entry.value as String).startsWith('http'), isTrue,
              reason: 'Version ${entry.key} URL in $id must start with http/https');
        }

        // Exec / CLI file checks
        if (app['exec_file'] != null) {
          expect(app['exec_file'], isA<String>());
          // In Linux, binaries should not end with .exe or .bat
          final exec = app['exec_file'] as String;
          if (exec != 'index.php') {
            expect(exec.endsWith('.exe'), isFalse,
                reason: 'Linux exec_file $exec for $id should not have .exe extension');
            expect(exec.endsWith('.bat'), isFalse,
                reason: 'Linux exec_file $exec for $id should not have .bat extension');
          }
        }
        if (app['cli_file'] != null) {
          expect(app['cli_file'], isA<String>());
          final cli = app['cli_file'] as String;
          if (cli != 'index.php') {
            expect(cli.endsWith('.exe'), isFalse,
                reason: 'Linux cli_file $cli for $id should not have .exe extension');
            expect(cli.endsWith('.bat'), isFalse,
                reason: 'Linux cli_file $cli for $id should not have .bat extension');
          }
        }
      }
    });

    test('linux catalog excludes source-only apps pending prebuilt sources',
        () async {
      final apps = await loadApps();
      final ids = apps.map((a) => a['id'] as String).toSet();
      expect(ids, isNot(contains('nginx')));
      expect(ids, isNot(contains('apache')));
      expect(ids, isNot(contains('redis')));
    });

    test('postgresql points at Zonky prebuilt jars on Maven Central', () async {
      final apps = await loadApps();
      final pg = apps.firstWhere((a) => a['id'] == 'postgresql');
      final versions = pg['versions'] as Map<String, dynamic>;
      expect(versions, isNotEmpty);
      for (final url in versions.values) {
        expect(url, startsWith('https://repo1.maven.org/maven2/'));
        expect(url, contains('embedded-postgres-binaries-linux-amd64'));
        expect(url, endsWith('.jar'));
      }
    });

    test('static-php entries expose the CLI binary as exec_file', () async {
      final apps = await loadApps();
      final phpApps = apps.where(
          (a) => (a['id'] as String).startsWith('php') && a['id'] != 'phpMyAdmin');
      expect(phpApps, isNotEmpty);
      for (final app in phpApps) {
        expect(app['exec_file'], equals('php'),
            reason: '${app['id']} ships the static-php-cli CLI binary');
        expect(app['cli_file'], equals('php'));
      }
    });

    test('AppsRepository.catalogFileNameFor returns OS-aware file names', () {
      expect(AppsRepository.catalogFileNameFor(isLinux: true), 'apps-linux.json');
      expect(AppsRepository.catalogFileNameFor(isLinux: false), 'apps.json');
    });
  });
}
