import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:dev_stack/features/apps/data/apps_repository.dart';
import 'package:dev_stack/features/apps/domain/installed_app.dart';

void main() {
  group('AppsRepository', () {
    group('catalogFileNameFor', () {
      test('returns apps-linux.json when isLinux is true', () {
        expect(
          AppsRepository.catalogFileNameFor(isLinux: true),
          equals('apps-linux.json'),
        );
      });

      test('returns apps.json when isLinux is false', () {
        expect(
          AppsRepository.catalogFileNameFor(isLinux: false),
          equals('apps.json'),
        );
      });
    });

    group('mergeAppsCatalog', () {
      test('returns empty list when catalog json is empty', () {
        final result = AppsRepository.mergeAppsCatalog([], {});
        expect(result, isEmpty);
      });

      test('maps uninstalled app with single category string and version list', () {
        final catalog = [
          {
            'id': 'nodejs',
            'name': 'Node.js',
            'description': 'JavaScript runtime built on V8',
            'category': 'runtime',
            'group_name': 'nodejs',
            'exec_file': 'node.exe',
            'cli_file': 'node.exe',
            'versions': {
              '22.14.0': 'https://nodejs.org/dist/v22.14.0/node-v22.14.0-win-x64.zip',
              '20.18.3': 'https://nodejs.org/dist/v20.18.3/node-v20.18.3-win-x64.zip',
            },
            'install_method': 'download',
            'default_username': 'root',
            'default_password': 'secret',
          }
        ];

        final result = AppsRepository.mergeAppsCatalog(catalog, {});

        expect(result.length, equals(1));
        final app = result.first;
        expect(app.appId, equals('nodejs'));
        expect(app.name, equals('Node.js'));
        expect(app.description, equals('JavaScript runtime built on V8'));
        expect(app.categories, equals(['runtime']));
        expect(app.groupName, equals('nodejs'));
        expect(app.execFile, equals('node.exe'));
        expect(app.cliFile, equals('node.exe'));
        expect(app.versions, equals(['22.14.0', '20.18.3']));
        expect(app.installMethod, equals('download'));
        expect(app.defaultUsername, equals('root'));
        expect(app.defaultPassword, equals('secret'));

        // Installation state should be uninstalled
        expect(app.isInstalled, isFalse);
        expect(app.status, equals('not_installed'));
        expect(app.location, isNull);
        expect(app.installedVersion, isNull);
        expect(app.installedAt, isNull);
        expect(app.execFilePath, isNull);
        expect(app.cliFilePath, isNull);
        expect(app.isAddedToPath, isFalse);
        expect(app.autoStartService, isFalse);
        expect(app.isDefault, isFalse);
        expect(app.extraInfoJson, isNull);
        expect(app.packageManagerCommandsJson, isNull);
      });

      test('maps app with category as list and empty versions fallback to latest', () {
        final catalog = [
          {
            'id': 'multi-cat-tool',
            'name': 'Multi Category Tool',
            'category': ['tools', 'developer'],
            'versions': {},
          }
        ];

        final result = AppsRepository.mergeAppsCatalog(catalog, {});

        expect(result.length, equals(1));
        final app = result.first;
        expect(app.categories, equals(['tools', 'developer']));
        expect(app.versions, equals(['latest']));
      });

      test('merges installed app state correctly from installedMap', () {
        final catalog = [
          {
            'id': 'nginx',
            'name': 'Nginx',
            'category': 'webserver',
            'versions': {
              '1.26.2': 'https://nginx.org/download/nginx-1.26.2.zip',
            },
          }
        ];

        final installTime = DateTime(2026, 8, 15, 10, 30);
        final installedApp = InstalledApp(
          appId: 'nginx',
          appName: 'Nginx',
          location: 'C:\\tools\\nginx',
          status: 'running',
          version: '1.26.2',
          installedAt: installTime,
          execFilePath: 'C:\\tools\\nginx\\nginx.exe',
          cliFilePath: 'C:\\tools\\nginx\\nginx.exe',
          addedToPath: true,
          autoStartService: true,
          groupName: 'webservers',
          isDefault: true,
        );

        final result = AppsRepository.mergeAppsCatalog(
          catalog,
          {'nginx': installedApp},
        );

        expect(result.length, equals(1));
        final app = result.first;
        expect(app.isInstalled, isTrue);
        expect(app.status, equals('running'));
        expect(app.location, equals('C:\\tools\\nginx'));
        expect(app.installedVersion, equals('1.26.2'));
        expect(app.installedAt, equals(installTime));
        expect(app.execFilePath, equals('C:\\tools\\nginx\\nginx.exe'));
        expect(app.cliFilePath, equals('C:\\tools\\nginx\\nginx.exe'));
        expect(app.isAddedToPath, isTrue);
        expect(app.autoStartService, isTrue);
        expect(app.isDefault, isTrue);
      });

      test('resolves LTS metadata from catalog extra', () {
        final catalog = [
          {
            'id': 'nodejs',
            'name': 'Node.js',
            'category': 'runtime',
            'extra': {
              'lts': '22.14.0',
              'lts_labels': {'22.14.0': 'Iron', '20.18.3': 'Hydrogen'},
            },
          }
        ];

        final result = AppsRepository.mergeAppsCatalog(catalog, {});
        expect(result.first.extraInfo['lts'], equals('22.14.0'));
        expect(
          result.first.extraInfo['lts_labels'],
          equals({'22.14.0': 'Iron', '20.18.3': 'Hydrogen'}),
        );
      });

      test('resolves LTS metadata from catalog extra_info', () {
        final catalog = [
          {
            'id': 'nodejs',
            'name': 'Node.js',
            'category': 'runtime',
            'extra_info': {
              'lts': '20.18.3',
            },
          }
        ];

        final result = AppsRepository.mergeAppsCatalog(catalog, {});
        expect(result.first.extraInfo['lts'], equals('20.18.3'));
      });

      test('resolves LTS metadata from top-level lts and lts_labels fields', () {
        final catalog = [
          {
            'id': 'nodejs',
            'name': 'Node.js',
            'category': 'runtime',
            'lts': '22.14.0',
            'lts_labels': {'22.14.0': 'Iron'},
          }
        ];

        final result = AppsRepository.mergeAppsCatalog(catalog, {});
        expect(result.first.extraInfo['lts'], equals('22.14.0'));
        expect(result.first.extraInfo['lts_labels'], equals({'22.14.0': 'Iron'}));
      });

      test('prefers installed app extraInfoJson override over catalog extra metadata', () {
        final catalog = [
          {
            'id': 'nodejs',
            'name': 'Node.js',
            'category': 'runtime',
            'extra': {'lts': '20.0.0'},
          }
        ];

        final installed = InstalledApp(
          appId: 'nodejs',
          appName: 'Node.js',
          location: '/opt/nodejs',
          status: 'stopped',
          extraInfoJson: jsonEncode({'lts': '22.14.0', 'custom_key': 'custom_val'}),
        );

        final result = AppsRepository.mergeAppsCatalog(catalog, {'nodejs': installed});
        expect(result.first.extraInfo['lts'], equals('22.14.0'));
        expect(result.first.extraInfo['custom_key'], equals('custom_val'));
      });

      test('falls back to catalog extra metadata when installed extraInfoJson is empty', () {
        final catalog = [
          {
            'id': 'nodejs',
            'name': 'Node.js',
            'category': 'runtime',
            'extra': {'lts': '22.14.0'},
          }
        ];

        final installed = InstalledApp(
          appId: 'nodejs',
          appName: 'Node.js',
          location: '/opt/nodejs',
          status: 'stopped',
          extraInfoJson: '',
        );

        final result = AppsRepository.mergeAppsCatalog(catalog, {'nodejs': installed});
        expect(result.first.extraInfo['lts'], equals('22.14.0'));
      });

      test('correctly parses package_manager_commands for Linux distributions', () {
        final catalog = [
          {
            'id': 'php8.4',
            'name': 'PHP 8.4',
            'category': 'runtime',
            'install_method': 'package_manager',
            'package_manager_commands': {
              'ubuntu': [
                'sudo apt-get update',
                'sudo apt-get install -y php8.4-cli',
              ],
              'fedora': [
                'sudo dnf install -y php',
              ],
            },
          }
        ];

        final result = AppsRepository.mergeAppsCatalog(catalog, {});
        final app = result.first;

        expect(app.installMethod, equals('package_manager'));
        expect(app.packageManagerCommandsJson, isNotNull);
        expect(
          app.packageManagerCommands['ubuntu'],
          equals(['sudo apt-get update', 'sudo apt-get install -y php8.4-cli']),
        );
        expect(
          app.packageManagerCommands['fedora'],
          equals(['sudo dnf install -y php']),
        );
      });
    });
  });
}
