import 'package:dev_stack/features/apps/data/linux_php_extension_driver.dart';
import 'package:dev_stack/features/apps/data/package_command_validator.dart';
import 'package:dev_stack/features/apps/data/php_extension_drivers/arch_php_extension_driver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final driver = ArchPhpExtensionDriver();
  const extDir = '/usr/lib/php/modules';

  group('ArchPhpExtensionDriver commands', () {
    test('discovers packages with pacman -Ss', () {
      expect(
        driver.packageListCommands('8.5'),
        equals(['pacman -Ss php-']),
      );
    });

    test('discovers file lists with pacman -Fl for candidate packages', () {
      final packages = [
        const PackageCandidate(name: 'php-gd'),
        const PackageCandidate(name: 'php-sqlite'),
      ];
      expect(
        driver.fileListCommands('8.5', packages),
        equals(['pacman -Fl php-gd php-sqlite']),
      );
    });

    test('falls back to bare pacman -Fl when candidate package list is empty', () {
      expect(
        driver.fileListCommands('8.5', const []),
        equals(['pacman -Fl']),
      );
    });

    test('installs with pacman -S --noconfirm', () {
      expect(
        driver.installCommands(
          const PackageCandidate(name: 'php-gd'),
          '8.5',
        ),
        equals(['pacman -S --noconfirm php-gd']),
      );
    });

    test('enables and disables through ownIniFile strategy (empty command lists)', () {
      expect(driver.iniStrategy, PhpIniStrategy.ownIniFile);
      expect(driver.enableCommands('8.5', 'gd'), isEmpty);
      expect(driver.disableCommands('8.5', 'gd'), isEmpty);
      expect(driver.iniFileNameFor('gd'), equals('99-ponta-gd.ini'));
    });

    test('every generated command passes PackageCommandValidator', () {
      for (final cmd in [
        ...driver.packageListCommands('8.5'),
        ...driver.fileListCommands('8.5', const [PackageCandidate(name: 'php-gd')]),
        ...driver.installCommands(const PackageCandidate(name: 'php-gd'), '8.5'),
      ]) {
        expect(PackageCommandValidator.validate(cmd), isNull, reason: 'rejected: $cmd');
      }
    });
  });

  group('ArchPhpExtensionDriver parsing', () {
    test('parses repo/name version lines with indented descriptions', () {
      const stdout = '''
extra/php 8.4.11-1
    A general-purpose scripting language
extra/php-gd 8.4.11-1
    GD extension for PHP
extra/php-sqlite 8.4.11-1
    sqlite extension for PHP
extra/php-apache 8.4.11-1
    Apache SAPI for PHP
''';
      final candidates = driver.parsePackageList(stdout, '8.5');

      expect(candidates.map((c) => c.name), equals([
        'php',
        'php-gd',
        'php-sqlite',
        'php-apache',
      ]));
      expect(candidates[1].description, equals('GD extension for PHP'));
      expect(candidates[2].description, equals('sqlite extension for PHP'));
    });

    test('ignores blank lines and drops unsafe package names', () {
      const stdout = '''
extra/php-gd 8.4.11-1
    GD extension for PHP

extra/php-bad;rm 8.4.11-1
    Bad
''';
      final candidates = driver.parsePackageList(stdout, '8.5');
      expect(candidates.map((c) => c.name), equals(['php-gd']));
    });

    test('parseFileListLine handles pacman relative paths and prepends slash', () {
      final entry = driver.parseFileListLine('php-gd usr/lib/php/modules/gd.so');
      expect(entry, isNotNull);
      expect(entry!.package, equals('php-gd'));
      expect(entry.path, equals('/usr/lib/php/modules/gd.so'));
    });

    test('parseFileList filters to extensionDir and excludes runtime libraries', () {
      // Arch real data:
      // php-gd ships usr/lib/php/modules/gd.so
      // php-sqlite ships usr/lib/php/modules/pdo_sqlite.so and sqlite3.so
      // php-apache ships usr/lib/httpd/modules/libphp.so (junk: outside extensionDir)
      // php ships usr/bin/php (not .so)
      const stdout = '''
php-gd usr/lib/php/modules/gd.so
php-sqlite usr/lib/php/modules/pdo_sqlite.so
php-sqlite usr/lib/php/modules/sqlite3.so
php-apache usr/lib/httpd/modules/libphp.so
php usr/bin/php
''';
      final byPackage = driver.parseFileList(stdout, extDir);

      expect(byPackage['php-gd'], equals(['gd']));
      expect(byPackage['php-sqlite'], equals(['pdo_sqlite', 'sqlite3']));
      expect(byPackage.containsKey('php-apache'), isFalse);
      expect(byPackage.containsKey('php'), isFalse);
    });

    test('combine matches Arch packages with discovered extensions', () {
      final packages = driver.parsePackageList('''
extra/php 8.4.11-1
    A general-purpose scripting language
extra/php-gd 8.4.11-1
    GD extension for PHP
extra/php-sqlite 8.4.11-1
    sqlite extension for PHP
extra/php-apache 8.4.11-1
    Apache SAPI for PHP
''', '8.5');

      final files = driver.parseFileList('''
php-gd usr/lib/php/modules/gd.so
php-sqlite usr/lib/php/modules/pdo_sqlite.so
php-sqlite usr/lib/php/modules/sqlite3.so
php-apache usr/lib/httpd/modules/libphp.so
''', extDir);

      final combined = driver.combine(packages, files);

      expect(combined.map((c) => c.name), equals(['php-gd', 'php-sqlite']));
      expect(combined[0].extensionNames, equals(['gd']));
      expect(combined[1].extensionNames, equals(['pdo_sqlite', 'sqlite3']));
      expect(combined[0].description, equals('GD extension for PHP'));
    });
  });
}
