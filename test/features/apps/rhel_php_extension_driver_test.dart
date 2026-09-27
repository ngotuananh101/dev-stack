import 'package:dev_stack/features/apps/data/linux_php_extension_driver.dart';
import 'package:dev_stack/features/apps/data/package_command_validator.dart';
import 'package:dev_stack/features/apps/data/php_extension_drivers/rhel_php_extension_driver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final driver = RhelPhpExtensionDriver();
  const extDir = '/usr/lib64/php/modules';

  group('RhelPhpExtensionDriver commands', () {
    test('discovers packages and file lists using dnf repoquery for both modular and SCL patterns', () {
      expect(
        driver.packageListCommands('8.5'),
        equals(["dnf repoquery --qf '[%{=NAME}\\n]' 'php-*' 'php85-php-*'"]),
      );
      expect(
        driver.fileListCommands('8.5', const []),
        equals(["dnf repoquery -l --qf '[%{=NAME} %{FILENAMES}\\n]' 'php-*' 'php85-php-*'"]),
      );
    });

    test('installs with dnf install -y', () {
      expect(
        driver.installCommands(
          const PackageCandidate(name: 'php-pdo'),
          '8.5',
        ),
        equals(['dnf install -y php-pdo']),
      );
    });

    test('enables and disables through ownIniFile strategy (empty command lists)', () {
      expect(driver.iniStrategy, PhpIniStrategy.ownIniFile);
      expect(driver.enableCommands('8.5', 'redis'), isEmpty);
      expect(driver.disableCommands('8.5', 'redis'), isEmpty);
      expect(driver.iniFileNameFor('redis'), equals('99-ponta-redis.ini'));
    });

    test('every generated command passes PackageCommandValidator', () {
      for (final cmd in [
        ...driver.packageListCommands('8.5'),
        ...driver.fileListCommands('8.5', const []),
        ...driver.installCommands(const PackageCandidate(name: 'php-pdo'), '8.5'),
      ]) {
        expect(PackageCommandValidator.validate(cmd), isNull, reason: 'rejected: $cmd');
      }
    });
  });

  group('RhelPhpExtensionDriver parsing', () {
    test('parses dnf repoquery name lines into package candidates', () {
      const stdout = '''
php-common
php-pdo
php-pecl-redis6
php-embedded
php-fpm
''';
      final candidates = driver.parsePackageList(stdout, '8.5');

      expect(candidates.map((c) => c.name), equals([
        'php-common',
        'php-pdo',
        'php-pecl-redis6',
        'php-embedded',
        'php-fpm',
      ]));
    });

    test('ignores blank lines and drops unsafe names in package list', () {
      const stdout = '''

php-pdo
php-unsafe; rm -rf /

php-fpm
''';
      final candidates = driver.parsePackageList(stdout, '8.5');
      expect(candidates.map((c) => c.name), equals(['php-pdo', 'php-fpm']));
    });

    test('parseFileListLine parses space-separated pkg and path with leading slash', () {
      final entry = driver.parseFileListLine('php-common /usr/lib64/php/modules/bz2.so');
      expect(entry, isNotNull);
      expect(entry!.package, equals('php-common'));
      expect(entry.path, equals('/usr/lib64/php/modules/bz2.so'));
    });

    test('parseFileList filters to extensionDir and excludes runtime libraries', () {
      // Real Remi repository files:
      // php-common ships multiple .so and .ini files
      // php-pdo ships pdo, pdo_sqlite, sqlite3
      // php-pecl-redis6 ships redis.so (name != extension)
      // php-embedded ships /usr/lib64/libphp.so (junk: outside extensionDir)
      // php-fpm ships /usr/sbin/php-fpm (not .so)
      const stdout = '''
php-common /usr/lib64/php/modules/bz2.so
php-common /usr/lib64/php/modules/curl.so
php-common /etc/php.d/20-bz2.ini
php-pdo /usr/lib64/php/modules/pdo.so
php-pdo /usr/lib64/php/modules/pdo_sqlite.so
php-pdo /usr/lib64/php/modules/sqlite3.so
php-pecl-redis6 /usr/lib64/php/modules/redis.so
php-embedded /usr/lib64/libphp.so
php-fpm /usr/sbin/php-fpm
''';
      final byPackage = driver.parseFileList(stdout, extDir);

      expect(byPackage['php-common'], equals(['bz2', 'curl']));
      expect(byPackage['php-pdo'], equals(['pdo', 'pdo_sqlite', 'sqlite3']));
      expect(byPackage['php-pecl-redis6'], equals(['redis']));
      expect(byPackage.containsKey('php-embedded'), isFalse);
      expect(byPackage.containsKey('php-fpm'), isFalse);
    });

    test('parseFileList handles Remi SCL paths under /opt/remi', () {
      const sclExtDir = '/opt/remi/php85/root/usr/lib64/php/modules';
      const stdout = '''
php85-php-common /opt/remi/php85/root/usr/lib64/php/modules/bz2.so
php85-php-common /opt/remi/php85/root/usr/lib64/php/modules/curl.so
php85-php-common /etc/opt/remi/php85/php.d/20-bz2.ini
php85-php-pecl-redis6 /opt/remi/php85/root/usr/lib64/php/modules/redis.so
php85-php-fpm /opt/remi/php85/root/usr/sbin/php-fpm
''';
      final byPackage = driver.parseFileList(stdout, sclExtDir);

      expect(byPackage['php85-php-common'], equals(['bz2', 'curl']));
      expect(byPackage['php85-php-pecl-redis6'], equals(['redis']));
      expect(byPackage.containsKey('php85-php-fpm'), isFalse);
    });

    test('combine matches packages with their discovered extensions', () {
      final packages = driver.parsePackageList('''
php-common
php-pdo
php-pecl-redis6
php-embedded
php-fpm
''', '8.5');

      final files = driver.parseFileList('''
php-common /usr/lib64/php/modules/bz2.so
php-common /usr/lib64/php/modules/curl.so
php-pdo /usr/lib64/php/modules/pdo.so
php-pdo /usr/lib64/php/modules/sqlite3.so
php-pecl-redis6 /usr/lib64/php/modules/redis.so
php-embedded /usr/lib64/libphp.so
''', extDir);

      final combined = driver.combine(packages, files);

      expect(combined.map((c) => c.name), equals(['php-common', 'php-pdo', 'php-pecl-redis6']));
      expect(combined[0].extensionNames, equals(['bz2', 'curl']));
      expect(combined[1].extensionNames, equals(['pdo', 'sqlite3']));
      expect(combined[2].extensionNames, equals(['redis']));
    });
  });
}
