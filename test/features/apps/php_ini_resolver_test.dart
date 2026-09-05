import 'package:dev_stack/features/apps/data/php_settings_provider.dart';
import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  AppModel createApp({
    String appId = 'php82',
    String? location = 'system_package',
  }) {
    return AppModel(
      appId: appId,
      name: 'PHP',
      categories: ['runtime'],
      location: location,
    );
  }

  group('resolvePhpIniFile & resolvePhpIniPath', () {
    test('Test 1: Windows standalone app -> returns <location>/php.ini', () {
      final app = createApp(location: r'C:\dev-stack\apps\php\8.2');
      final resolvedPath = resolvePhpIniPath(app, isLinux: false);
      expect(resolvedPath, p.join(r'C:\dev-stack\apps\php\8.2', 'php.ini'));

      final resolvedFile = resolvePhpIniFile(app, isLinux: false);
      expect(resolvedFile, isNotNull);
      expect(resolvedFile!.path, p.join(r'C:\dev-stack\apps\php\8.2', 'php.ini'));
    });

    test('Test 2: Linux app with custom path location -> returns <location>/php.ini', () {
      final app = createApp(location: '/opt/custom/php82');
      final resolvedPath = resolvePhpIniPath(app, isLinux: true);
      expect(resolvedPath, '/opt/custom/php82/php.ini');

      final resolvedFile = resolvePhpIniFile(app, isLinux: true);
      expect(resolvedFile, isNotNull);
      expect(resolvedFile!.path, '/opt/custom/php82/php.ini');
    });

    test('Test 3: Linux app with system_package and php82: when /etc/php/8.2/fpm/php.ini exists -> chooses FPM ini', () {
      final app = createApp(appId: 'php82', location: 'system_package');
      final existingPaths = {'/etc/php/8.2/fpm/php.ini', '/etc/php.ini'};

      final resolvedPath = resolvePhpIniPath(
        app,
        isLinux: true,
        fileExists: (path) => existingPaths.contains(path),
      );
      expect(resolvedPath, '/etc/php/8.2/fpm/php.ini');

      final resolvedFile = resolvePhpIniFile(
        app,
        isLinux: true,
        fileExists: (path) => existingPaths.contains(path),
      );
      expect(resolvedFile, isNotNull);
      expect(resolvedFile!.path, '/etc/php/8.2/fpm/php.ini');
    });

    test('Test 4: Linux app with system_package and php83: when FPM does not exist but CLI ini exists -> chooses CLI ini', () {
      final app = createApp(appId: 'php83', location: 'system_package');
      final existingPaths = {'/etc/php/8.3/cli/php.ini'};

      final resolvedPath = resolvePhpIniPath(
        app,
        isLinux: true,
        fileExists: (path) => existingPaths.contains(path),
      );
      expect(resolvedPath, '/etc/php/8.3/cli/php.ini');

      final resolvedFile = resolvePhpIniFile(
        app,
        isLinux: true,
        fileExists: (path) => existingPaths.contains(path),
      );
      expect(resolvedFile, isNotNull);
      expect(resolvedFile!.path, '/etc/php/8.3/cli/php.ini');
    });

    test('Test 5: Linux app with system_package: when /etc/php.ini exists -> chooses /etc/php.ini', () {
      final app = createApp(appId: 'php84', location: 'system_package');
      final existingPaths = {'/etc/php.ini'};

      final resolvedPath = resolvePhpIniPath(
        app,
        isLinux: true,
        fileExists: (path) => existingPaths.contains(path),
      );
      expect(resolvedPath, '/etc/php.ini');

      final resolvedFile = resolvePhpIniFile(
        app,
        isLinux: true,
        fileExists: (path) => existingPaths.contains(path),
      );
      expect(resolvedFile, isNotNull);
      expect(resolvedFile!.path, '/etc/php.ini');
    });

    test('Test 6: Linux app with system_package: when no candidates exist -> fallbacks to /etc/php/<version>/fpm/php.ini', () {
      final app = createApp(appId: 'php82', location: 'system_package');

      final resolvedPath = resolvePhpIniPath(
        app,
        isLinux: true,
        fileExists: (path) => false,
      );
      expect(resolvedPath, '/etc/php/8.2/fpm/php.ini');

      final resolvedFile = resolvePhpIniFile(
        app,
        isLinux: true,
        fileExists: (path) => false,
      );
      expect(resolvedFile, isNotNull);
      expect(resolvedFile!.path, '/etc/php/8.2/fpm/php.ini');
    });

    test('Test 7: App with location == null or empty -> returns null', () {
      final appNullLocation = createApp(location: null);
      expect(resolvePhpIniPath(appNullLocation, isLinux: true), isNull);
      expect(resolvePhpIniPath(appNullLocation, isLinux: false), isNull);
      expect(resolvePhpIniFile(appNullLocation, isLinux: true), isNull);
      expect(resolvePhpIniFile(appNullLocation, isLinux: false), isNull);

      final appEmptyLocation = createApp(location: '');
      expect(resolvePhpIniPath(appEmptyLocation, isLinux: true), isNull);
      expect(resolvePhpIniPath(appEmptyLocation, isLinux: false), isNull);
      expect(resolvePhpIniFile(appEmptyLocation, isLinux: true), isNull);
      expect(resolvePhpIniFile(appEmptyLocation, isLinux: false), isNull);
    });

    test('Test 8: Remi candidate /etc/opt/remi/php85/php.ini is selected if earlier candidates do not exist', () {
      final app = createApp(appId: 'php85', location: 'system_package');
      final existingPaths = {'/etc/opt/remi/php85/php.ini'};

      final resolvedPath = resolvePhpIniPath(
        app,
        isLinux: true,
        fileExists: (path) => existingPaths.contains(path),
      );
      expect(resolvedPath, '/etc/opt/remi/php85/php.ini');
    });
  });
}
