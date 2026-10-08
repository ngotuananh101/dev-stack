import 'package:dev_stack/features/apps/data/linux_php_extension_driver.dart';
import 'package:dev_stack/features/apps/data/package_command_validator.dart';
import 'package:dev_stack/features/apps/data/php_extension_drivers/rhel_php_extension_driver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final driver = RhelPhpExtensionDriver();
  const extDir = '/usr/lib64/php/modules';

  group('RhelPhpExtensionDriver commands', () {
    test('lists packages with the dnf5-safe lowercase name tag', () {
      // dnf5 (Fedora 41+, EL10) dropped the rpm `%{=NAME}` tag and prints `[`
      // literally, so the old `--qf '[%{=NAME}\n]'` returned one junk line and
      // an empty package list. `%{name}` is the tag both dnf4 and dnf5 accept.
      expect(
        driver.packageListCommands('8.5'),
        equals(["dnf repoquery --qf '%{name}\\n' 'php-*' 'php85-php-*'"]),
      );
    });

    test('lists files with the dnf5 attribution form then the dnf4 bare form', () {
      // dnf5 forbids `-l` together with `--qf` (exit 2) and has no `%{FILENAMES}`
      // tag; its `%{name} %{files}` prints a block per package. dnf4 has no file
      // tag at all for `--qf`, so it can only print bare paths via `-l`. The
      // manager tries these in order and keeps the first that runs.
      expect(
        driver.fileListCommands('8.5', const []),
        equals([
          "dnf repoquery --qf '%{name} %{files}\\n' 'php-*' 'php85-php-*'",
          "dnf repoquery -l 'php-*' 'php85-php-*'",
        ]),
      );
    });

    test('resolves an unknown owner by exact file path with dnf repoquery -f', () {
      // `-f` is a filter (not a display mode), so it combines with `--qf` on
      // both dnf4 and dnf5 — the one form that yields `pkg` for a known path.
      expect(
        driver.resolveOwnerCommands(extDir, 'imagick'),
        equals(["dnf repoquery --qf '%{name}\\n' -f '$extDir/imagick.so'"]),
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
        ...driver.resolveOwnerCommands(extDir, 'imagick'),
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

    test('parseOwner takes the first safe package name from dnf -f output', () {
      expect(
        driver.parseOwner('php84-php-pecl-imagick-im7\n'),
        equals('php84-php-pecl-imagick-im7'),
      );
      // A hostile line is skipped, not sanitised into a usable name.
      expect(
        driver.parseOwner('bad name; rm -rf /\nphp84-php-gd\n'),
        equals('php84-php-gd'),
      );
      expect(driver.parseOwner(''), isNull);
    });

    test('parseFileListLine parses space-separated pkg and path with leading slash', () {
      final entry = driver.parseFileListLine('php-common /usr/lib64/php/modules/bz2.so');
      expect(entry, isNotNull);
      expect(entry!.package, equals('php-common'));
      expect(entry.path, equals('/usr/lib64/php/modules/bz2.so'));
    });

    test('parseFileListLine treats a bare path as an owner-less continuation', () {
      final entry = driver.parseFileListLine('/usr/lib64/php/modules/curl.so');
      expect(entry, isNotNull);
      expect(entry!.package, isNull);
      expect(entry.path, equals('/usr/lib64/php/modules/curl.so'));
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

    test('parseFileList attributes dnf5 block output (pkg line then bare paths)', () {
      // dnf5 `--qf '%{name} %{files}\n'` prints the package name once, on the
      // first line of its block; every later file is a bare path, and a blank
      // line separates one package from the next.
      const stdout = '''
php-common /usr/lib64/php/modules/bz2.so
/usr/lib64/php/modules/curl.so
/usr/lib64/libphp.so

php-pecl-redis6 /usr/lib64/php/modules/redis.so
''';
      final byPackage = driver.parseFileList(stdout, extDir);

      expect(byPackage['php-common'], equals(['bz2', 'curl']));
      expect(byPackage['php-pecl-redis6'], equals(['redis']));
    });

    test('parseFileList files dnf4 bare -l output under the unknown-owner bucket', () {
      // dnf4 cannot print the package alongside its files, so every path is
      // owner-less. The owner is resolved later, on demand, with `-f`.
      const stdout = '''
/usr/lib64/php/modules/bz2.so
/usr/lib64/php/modules/curl.so
/usr/lib64/libphp.so
''';
      final byPackage = driver.parseFileList(stdout, extDir);

      expect(byPackage[''], equals(['bz2', 'curl']));
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

    test('combine emits one unknown-owner candidate from the bare bucket', () {
      final combined = driver.combine(
        driver.parsePackageList('php-common\n', '8.5'),
        const {'': ['bz2', 'curl']},
      );

      expect(combined.length, equals(1));
      expect(combined.single.hasPackage, isFalse);
      expect(combined.single.ownerUnknown, isTrue);
      expect(combined.single.extensionNames, equals(['bz2', 'curl']));
    });
  });
}
