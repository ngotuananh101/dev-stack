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

        final isPackageManager = app['install_method'] == 'package_manager';
        for (final entry in versions.entries) {
          expect(entry.key, isNotEmpty, reason: 'Version key in $id should not be empty');
          expect(entry.value, isA<String>(),
              reason: 'Version ${entry.key} value in $id must be string');
          if (isPackageManager) {
            // Package-manager apps use a sentinel value instead of a URL
            expect(entry.value, equals('package_manager'),
                reason: 'Version ${entry.key} of package_manager app $id '
                    'must use the package_manager sentinel');
          } else {
            expect((entry.value as String).startsWith('http'), isTrue,
                reason: 'Version ${entry.key} URL in $id must start with http/https');
          }
        }

        // Package-manager apps must ship per-distro commands
        if (isPackageManager) {
          final cmds = app['package_manager_commands'];
          expect(cmds, isA<Map<String, dynamic>>(),
              reason: 'package_manager app $id must define package_manager_commands');
          final cmdMap = cmds as Map<String, dynamic>;
          expect(cmdMap.keys, containsAll(['ubuntu', 'debian', 'centos']),
              reason: 'package_manager app $id must cover ubuntu/debian/centos');
          for (final list in cmdMap.values) {
            expect(list, isA<List>(), reason: 'Commands in $id must be a list');
            expect((list as List), isNotEmpty,
                reason: 'Distro command list in $id must not be empty');
          }
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

    test('linux catalog includes package-managed apache, redis, and postgresql',
        () async {
      final apps = await loadApps();
      final ids = apps.map((a) => a['id'] as String).toSet();
      expect(ids, contains('nginx')); // Nginx is supported via Jirutka static binaries
      // Apache, Redis, and PostgreSQL are now installed via the system package
      // manager with isolated foreground runtime configuration.
      expect(ids, contains('apache'));
      expect(ids, contains('redis'));
      expect(ids, contains('postgresql'));
    });

    test('apache installs via package_manager with per-distro commands', () async {
      final apps = await loadApps();
      final apache = apps.firstWhere((a) => a['id'] == 'apache');
      expect(apache['install_method'], equals('package_manager'));
      final versions = apache['versions'] as Map<String, dynamic>;
      expect(versions['system'], equals('package_manager'));
      final cmds = apache['package_manager_commands'] as Map<String, dynamic>;
      expect(cmds.keys, containsAll(['ubuntu', 'debian', 'centos']));
      // Ubuntu/Debian install apache2; CentOS installs httpd.
      expect((cmds['ubuntu'] as List).last, contains('apache2'));
      expect((cmds['centos'] as List).last, contains('httpd'));
    });

    test('redis installs via package_manager with systemctl disable commands',
        () async {
      final apps = await loadApps();
      final redis = apps.firstWhere((a) => a['id'] == 'redis');
      expect(redis['install_method'], equals('package_manager'));
      final versions = redis['versions'] as Map<String, dynamic>;
      expect(versions['system'], equals('package_manager'));
      final cmds = redis['package_manager_commands'] as Map<String, dynamic>;
      expect(cmds.keys, containsAll(['ubuntu', 'debian', 'centos']));
      // Each distro command list ends with a systemctl disable directive.
      for (final list in cmds.values) {
        expect((list as List).last, contains('systemctl disable'));
      }
    });

    test('postgresql installs via package_manager with systemctl disable commands',
        () async {
      final apps = await loadApps();
      final pg = apps.firstWhere((a) => a['id'] == 'postgresql');
      expect(pg['install_method'], equals('package_manager'));
      final versions = pg['versions'] as Map<String, dynamic>;
      expect(versions['system'], equals('package_manager'));
      final cmds = pg['package_manager_commands'] as Map<String, dynamic>;
      expect(cmds.keys, containsAll(['ubuntu', 'debian', 'centos']));
      for (final list in cmds.values) {
        expect((list as List).last, contains('systemctl disable'));
      }
    });

    test('nginx points at Jirutka static Linux binaries', () async {
      final apps = await loadApps();
      final nginx = apps.firstWhere((a) => a['id'] == 'nginx');
      final versions = nginx['versions'] as Map<String, dynamic>;
      expect(versions, isNotEmpty);
      for (final url in versions.values) {
        expect(url, startsWith('https://jirutka.github.io/nginx-binaries/bin/nginx-'));
        expect(url, contains('-x86_64-linux'));
      }
    });

    test('php entries use package_manager install with versioned exec_file',
        () async {
      final apps = await loadApps();
      final phpApps = apps.where(
          (a) => (a['id'] as String).startsWith('php') && a['id'] != 'phpMyAdmin');
      expect(phpApps, isNotEmpty);
      for (final app in phpApps) {
        expect(app['install_method'], equals('package_manager'),
            reason: '${app['id']} installs via system package manager on Linux');
        // Versioned FPM binary (php-fpm8.5, php-fpm8.4, ...) provided by
        // distro packages; the CLI binary (php8.5) is resolved separately
        // via cli_file.
        final exec = app['exec_file'] as String?;
        expect(exec, isNotNull, reason: '${app['id']} must define exec_file');
        expect(exec, matches(RegExp(r'^php-fpm[\d.]+$')),
            reason: '${app['id']} exec_file should be versioned FPM (e.g. php-fpm8.5)');
      }
    });

    test('package_manager php commands contain no shell substitution', () async {
      final apps = await loadApps();
      final phpApps = apps.where(
          (a) => (a['id'] as String).startsWith('php') && a['id'] != 'phpMyAdmin');
      for (final app in phpApps) {
        final cmds = app['package_manager_commands'] as Map<String, dynamic>;
        for (final list in cmds.values) {
          for (final cmd in (list as List).cast<String>()) {
            expect(cmd.contains(r'$('), isFalse,
                reason: '${app['id']} command uses shell substitution: $cmd');
            expect(cmd.contains('`'), isFalse,
                reason: '${app['id']} command uses backticks: $cmd');
            expect(cmd.contains('lsb_release'), isFalse,
                reason: '${app['id']} must use {codename} placeholder, '
                    'not lsb_release: $cmd');
          }
        }
      }
    });

    test('AppsRepository.catalogFileNameFor returns OS-aware file names', () {
      expect(AppsRepository.catalogFileNameFor(isLinux: true), 'apps-linux.json');
      expect(AppsRepository.catalogFileNameFor(isLinux: false), 'apps.json');
    });
  });
}
