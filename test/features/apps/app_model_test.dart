import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppModel - Version Comparison', () {
    test('isVersionNewer returns true when new version is higher', () {
      final app = AppModel(
        appId: 'test',
        name: 'Test',
        categories: [],
      );

      expect(app.isVersionNewer('8.2.5', '8.2.3'), isTrue);
      expect(app.isVersionNewer('8.3.0', '8.2.9'), isTrue);
      expect(app.isVersionNewer('9.0.0', '8.2.5'), isTrue);
    });

    test('isVersionNewer returns false when new version is lower', () {
      final app = AppModel(
        appId: 'test',
        name: 'Test',
        categories: [],
      );

      expect(app.isVersionNewer('8.2.3', '8.2.5'), isFalse);
      expect(app.isVersionNewer('8.2.9', '8.3.0'), isFalse);
      expect(app.isVersionNewer('8.2.5', '9.0.0'), isFalse);
    });

    test('isVersionNewer returns false when versions are equal', () {
      final app = AppModel(
        appId: 'test',
        name: 'Test',
        categories: [],
      );

      expect(app.isVersionNewer('8.2.5', '8.2.5'), isFalse);
      expect(app.isVersionNewer('9.0.0', '9.0.0'), isFalse);
    });

    test('isVersionNewer handles different version lengths', () {
      final app = AppModel(
        appId: 'test',
        name: 'Test',
        categories: [],
      );

      expect(app.isVersionNewer('8.2.5.1', '8.2.5'), isTrue);
      expect(app.isVersionNewer('8.2.5', '8.2.5.1'), isFalse);
      expect(app.isVersionNewer('8.2', '8.1.9'), isTrue);
    });

    test('isVersionNewer handles non-numeric version parts gracefully', () {
      final app = AppModel(
        appId: 'test',
        name: 'Test',
        categories: [],
      );

      // Should treat non-numeric as 0
      expect(app.isVersionNewer('8.2.x', '8.2.5'), isFalse);
      expect(app.isVersionNewer('8.3.x', '8.2.5'), isTrue);
    });
  });

  group('AppModel - Update Detection', () {
    test('hasUpdateAvailable detects patch updates', () {
      final app = AppModel(
        appId: 'php82',
        name: 'PHP 8.2',
        categories: ['language'],
        installedVersion: '8.2.3',
        versions: ['8.2.3', '8.2.5', '8.2.10', '8.3.0'],
        isInstalled: true,
      );

      expect(app.hasUpdateAvailable, isTrue);
    });

    test('hasUpdateAvailable ignores different major.minor branches', () {
      final app = AppModel(
        appId: 'php82',
        name: 'PHP 8.2',
        categories: ['language'],
        installedVersion: '8.2.10',
        versions: ['8.2.10', '8.3.0', '8.3.5', '9.0.0'],
        isInstalled: true,
      );

      expect(app.hasUpdateAvailable, isFalse);
    });

    test('hasUpdateAvailable returns false when on latest patch', () {
      final app = AppModel(
        appId: 'php82',
        name: 'PHP 8.2',
        categories: ['language'],
        installedVersion: '8.2.10',
        versions: ['8.2.5', '8.2.8', '8.2.10', '8.3.0'],
        isInstalled: true,
      );

      expect(app.hasUpdateAvailable, isFalse);
    });

    test('hasUpdateAvailable returns false when not installed', () {
      final app = AppModel(
        appId: 'php82',
        name: 'PHP 8.2',
        categories: ['language'],
        versions: ['8.2.3', '8.2.5', '8.2.10'],
        isInstalled: false,
      );

      expect(app.hasUpdateAvailable, isFalse);
    });

    test('hasUpdateAvailable returns false when no installedVersion', () {
      final app = AppModel(
        appId: 'php82',
        name: 'PHP 8.2',
        categories: ['language'],
        versions: ['8.2.3', '8.2.5', '8.2.10'],
        isInstalled: true,
      );

      expect(app.hasUpdateAvailable, isFalse);
    });

    test('hasUpdateAvailable skips "latest" in versions list', () {
      final app = AppModel(
        appId: 'php82',
        name: 'PHP 8.2',
        categories: ['language'],
        installedVersion: '8.2.3',
        versions: ['latest', '8.2.3', '8.2.5', '8.3.0'],
        isInstalled: true,
      );

      expect(app.hasUpdateAvailable, isTrue);
    });

    test('hasUpdateAvailable handles single-digit versions', () {
      final app = AppModel(
        appId: 'test',
        name: 'Test',
        categories: ['tool'],
        installedVersion: '8',
        versions: ['8', '9'],
        isInstalled: true,
      );

      // Should return false because version parts < 2
      expect(app.hasUpdateAvailable, isFalse);
    });
  });

  group('AppModel - Service Detection', () {
    test('isService returns true for database category', () {
      final app = AppModel(
        appId: 'mysql',
        name: 'MySQL',
        categories: ['database'],
      );

      expect(app.isService, isTrue);
    });

    test('isService returns true for webserver category', () {
      final app = AppModel(
        appId: 'nginx',
        name: 'Nginx',
        categories: ['webserver'],
      );

      expect(app.isService, isTrue);
    });

    test('isService returns true for storage category', () {
      final app = AppModel(
        appId: 'rustfs',
        name: 'RustFS',
        categories: ['storage'],
      );

      expect(app.isService, isTrue);
    });

    test('isService returns true for PHP apps', () {
      final app = AppModel(
        appId: 'php82',
        name: 'PHP 8.2',
        categories: ['language'],
      );

      expect(app.isService, isTrue);
    });

    test('isService returns false for phpMyAdmin', () {
      final app = AppModel(
        appId: 'phpmyadmin',
        name: 'phpMyAdmin',
        categories: ['database', 'tool'],
      );

      expect(app.isService, isFalse);
    });

    test('isService returns false for non-service categories', () {
      final app = AppModel(
        appId: 'git',
        name: 'Git',
        categories: ['tool'],
      );

      expect(app.isService, isFalse);
    });

    test('isService returns false for empty categories', () {
      final app = AppModel(
        appId: 'test',
        name: 'Test',
        categories: [],
      );

      expect(app.isService, isFalse);
    });
  });

  group('AppModel - Log Management', () {
    test('addServiceLog adds timestamped log', () {
      final app = AppModel(
        appId: 'test',
        name: 'Test',
        categories: [],
      );

      app.addServiceLog('Test message');

      expect(app.serviceLogs.length, equals(1));
      expect(app.serviceLogs.first, contains('Test message'));
      expect(app.serviceLogs.first, matches(r'\[\d{2}:\d{2}:\d{2}\]'));
    });

    test('addServiceLog limits to maxServiceLogEntries', () {
      final app = AppModel(
        appId: 'test',
        name: 'Test',
        categories: [],
      );

      // Add more than max entries
      for (var i = 0; i < AppModel.maxServiceLogEntries + 10; i++) {
        app.addServiceLog('Log $i');
      }

      expect(app.serviceLogs.length, equals(AppModel.maxServiceLogEntries));
      // Should keep the most recent ones
      expect(
        app.serviceLogs.last,
        contains('Log ${AppModel.maxServiceLogEntries + 9}'),
      );
    });

    test('addLog adds install log without timestamp', () {
      final app = AppModel(
        appId: 'test',
        name: 'Test',
        categories: [],
      );

      app.addLog('Install message');

      expect(app.installLogs.length, equals(1));
      expect(app.installLogs.first, equals('Install message'));
    });

    test('addLog limits to maxInstallLogEntries', () {
      final app = AppModel(
        appId: 'test',
        name: 'Test',
        categories: [],
      );

      // Add more than max entries
      for (var i = 0; i < AppModel.maxInstallLogEntries + 5; i++) {
        app.addLog('Install log $i');
      }

      expect(app.installLogs.length, equals(AppModel.maxInstallLogEntries));
      // Should keep the most recent ones
      expect(
        app.installLogs.last,
        contains('Install log ${AppModel.maxInstallLogEntries + 4}'),
      );
    });
  });

  group('AppModel - ExtraInfo Handling', () {
    test('extraInfo returns parsed JSON from extraInfoJson', () {
      final app = AppModel(
        appId: 'test',
        name: 'Test',
        categories: [],
        extraInfoJson: '{"port": 9000, "host": "localhost"}',
      );

      expect(app.extraInfo['port'], equals(9000));
      expect(app.extraInfo['host'], equals('localhost'));
    });

    test('extraInfo returns empty map when extraInfoJson is null', () {
      final app = AppModel(
        appId: 'test',
        name: 'Test',
        categories: [],
      );

      expect(app.extraInfo, isEmpty);
    });

    test('extraInfo returns empty map when extraInfoJson is invalid', () {
      final app = AppModel(
        appId: 'test',
        name: 'Test',
        categories: [],
        extraInfoJson: 'invalid json',
      );

      expect(app.extraInfo, isEmpty);
    });
  });

  group('AppModel - Construction', () {
    test('creates minimal AppModel with required fields', () {
      final app = AppModel(
        appId: 'minimal',
        name: 'Minimal App',
        categories: ['tool'],
      );

      expect(app.appId, equals('minimal'));
      expect(app.name, equals('Minimal App'));
      expect(app.categories, equals(['tool']));
      expect(app.isInstalled, isFalse);
      expect(app.versions, equals(['latest']));
    });

    test('creates full AppModel with all fields', () {
      final now = DateTime.now();
      final app = AppModel(
        appId: 'full',
        name: 'Full App',
        description: 'Full description',
        categories: ['database', 'server'],
        groupName: 'mysql',
        execFile: 'mysqld.exe',
        cliFile: 'mysql.exe',
        versions: ['8.0', '8.1', '8.2'],
        isInstalled: true,
        installedVersion: '8.1',
        installedAt: now,
        location: 'C:\\Apps\\mysql',
        execFilePath: 'C:\\Apps\\mysql\\bin\\mysqld.exe',
        cliFilePath: 'C:\\Apps\\mysql\\bin\\mysql.exe',
        isAddedToPath: true,
        addPathAfterInstall: true,
        autoStartService: true,
        isDefault: true,
      );

      expect(app.appId, equals('full'));
      expect(app.name, equals('Full App'));
      expect(app.description, equals('Full description'));
      expect(app.groupName, equals('mysql'));
      expect(app.isInstalled, isTrue);
      expect(app.installedVersion, equals('8.1'));
      expect(app.installedAt, equals(now));
      expect(app.autoStartService, isTrue);
    });
  });
}
