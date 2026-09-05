import 'package:flutter_test/flutter_test.dart';
import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:dev_stack/features/apps/data/apps_repository.dart';

void main() {
  group('AppModel & AppsRepository - Checksum Metadata Support (VULN-12)', () {
    test('AppModel versionSha256 returns empty map when versionSha256Json is null', () {
      final app = AppModel(
        appId: 'nodejs',
        name: 'Node.js',
        categories: ['runtime'],
      );

      expect(app.versionSha256, isEmpty);
    });

    test('AppModel versionSha256 parses and serializes versionSha256Json correctly', () {
      final app = AppModel(
        appId: 'nodejs',
        name: 'Node.js',
        categories: ['runtime'],
      );

      app.versionSha256 = {
        '25.9.0': 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        '25.8.2': 'ca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb',
      };

      expect(app.versionSha256.length, 2);
      expect(app.versionSha256['25.9.0'], 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
      expect(app.versionSha256['25.8.2'], 'ca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb');
      expect(app.versionSha256Json, contains('25.9.0'));
    });

    test('AppsRepository.mergeAppsCatalog parses sha256 map from catalog JSON', () {
      final catalog = [
        {
          'id': 'nodejs',
          'name': 'Node.js',
          'category': 'runtime',
          'versions': {
            '25.9.0': 'https://nodejs.org/dist/v25.9.0/node-v25.9.0-win-x64.zip',
          },
          'sha256': {
            '25.9.0': 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          },
        }
      ];

      final apps = AppsRepository.mergeAppsCatalog(catalog, {});
      expect(apps.length, 1);
      final app = apps.first;
      expect(app.versionSha256['25.9.0'], 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
    });

    test('AppsRepository.mergeAppsCatalog handles app without sha256 gracefully', () {
      final catalog = [
        {
          'id': 'python',
          'name': 'Python',
          'category': 'runtime',
          'versions': {
            '3.12.0': 'https://python.org/dist/python-3.12.0.zip',
          },
        }
      ];

      final apps = AppsRepository.mergeAppsCatalog(catalog, {});
      expect(apps.length, 1);
      final app = apps.first;
      expect(app.versionSha256, isEmpty);
      expect(app.versionSha256Json, isNull);
    });
  });
}
