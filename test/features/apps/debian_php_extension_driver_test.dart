import 'package:dev_stack/features/apps/data/linux_php_extension_driver.dart';
import 'package:dev_stack/features/apps/data/package_command_validator.dart';
import 'package:dev_stack/features/apps/data/php_extension_drivers/debian_php_extension_driver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final driver = DebianPhpExtensionDriver();
  const extDir = '/usr/lib/php/20250925';

  group('driverForFamily', () {
    test('maps ubuntu and debian to the Debian driver', () {
      expect(driverForFamily('ubuntu'), isA<DebianPhpExtensionDriver>());
      expect(driverForFamily('debian'), isA<DebianPhpExtensionDriver>());
    });

    test('returns null for unknown, which callers must treat as unsupported', () {
      expect(driverForFamily('unknown'), isNull);
      expect(driverForFamily('nixos'), isNull);
    });
  });

  group('isSafeName', () {
    test('accepts real package and extension names', () {
      expect(LinuxPhpExtensionDriver.isSafeName('mbstring'), isTrue);
      expect(LinuxPhpExtensionDriver.isSafeName('php8.5-mbstring'), isTrue);
      expect(LinuxPhpExtensionDriver.isSafeName('pdo_mysql'), isTrue);
      expect(LinuxPhpExtensionDriver.isSafeName('php-pecl-zip'), isTrue);
    });

    test('rejects injection attempts', () {
      expect(LinuxPhpExtensionDriver.isSafeName('mbstring; rm -rf /'), isFalse);
      expect(LinuxPhpExtensionDriver.isSafeName(r'a$(id)'), isFalse);
      expect(LinuxPhpExtensionDriver.isSafeName('a`id`'), isFalse);
      expect(LinuxPhpExtensionDriver.isSafeName('a b'), isFalse);
      expect(LinuxPhpExtensionDriver.isSafeName(''), isFalse);
      expect(LinuxPhpExtensionDriver.isSafeName('-flag'), isFalse);
    });
  });

  group('splitCommand', () {
    test('strips the single quotes so the pattern reaches the tool intact', () {
      // Discovery runs through Process.run (direct argv, no shell), so a kept
      // quote would arrive at apt-file as a literal character and the pattern
      // would match nothing — a silent empty extension list.
      expect(
        LinuxPhpExtensionDriver.splitCommand("apt-file list -x '^php8.5-'"),
        equals(['apt-file', 'list', '-x', '^php8.5-']),
      );
      expect(
        LinuxPhpExtensionDriver.splitCommand("dnf repoquery --qf '[%{=NAME}\\n]' 'php-*'"),
        equals(['dnf', 'repoquery', '--qf', '[%{=NAME}\\n]', 'php-*']),
      );
      // An unquoted command is unchanged.
      expect(
        LinuxPhpExtensionDriver.splitCommand('pacman -Ss php-'),
        equals(['pacman', '-Ss', 'php-']),
      );
      // A space inside quotes does not split the argument.
      expect(
        LinuxPhpExtensionDriver.splitCommand("dnf repoquery -l --qf '[%{=NAME} %{FILENAMES}\\n]' 'php-*'"),
        equals([
          'dnf',
          'repoquery',
          '-l',
          '--qf',
          '[%{=NAME} %{FILENAMES}\\n]',
          'php-*',
        ]),
      );
    });
  });

  group('disableIniPattern', () {
    test('is anchored so pdo cannot match pdo_mysql', () {
      final re = RegExp(driver.disableIniPattern('pdo'));
      expect(re.hasMatch('extension=pdo.so'), isTrue);
      expect(re.hasMatch('extension=pdo'), isTrue);
      expect(re.hasMatch('zend_extension="pdo.so"'), isTrue);
      expect(re.hasMatch('extension=/usr/lib64/php/modules/pdo.so'), isTrue);
      expect(re.hasMatch('  extension = pdo.so'), isTrue);
      expect(re.hasMatch('extension=pdo_mysql.so'), isFalse);
      expect(re.hasMatch('extension=pdo_pgsql.so'), isFalse);
    });

    test('gives opcache its directive form rather than a loader line', () {
      final pattern = driver.disableIniPattern('opcache');
      final re = RegExp(pattern);
      expect(re.hasMatch('opcache.enable=1'), isTrue);
      expect(re.hasMatch('opcache.enable = 0'), isTrue);
      // It must NOT match a loader line: there is no opcache.so to load.
      expect(re.hasMatch('extension=opcache.so'), isFalse);
    });

    test('contains no literal semicolon, which the validator forbids', () {
      // The `;` is emitted by sed as the escape `\x3b`; the pattern itself is
      // only the match side, so this guards the whole generated command.
      for (final name in ['pdo', 'opcache', 'mbstring', 'pdo_mysql']) {
        expect(driver.disableIniPattern(name), isNot(contains(';')));
      }
    });
  });

  group('DebianPhpExtensionDriver.parsePackageList', () {
    test('parses apt-cache search name - description lines', () {
      const stdout = '''
php8.5-mbstring - MBSTRING module for PHP
php8.5-curl - CURL module for PHP
php8.5-zip - Zip module for PHP
''';
      final candidates = driver.parsePackageList(stdout, '8.5');

      expect(candidates.length, equals(3));
      expect(candidates[0].name, 'php8.5-mbstring');
      expect(candidates[0].description, 'MBSTRING module for PHP');
      expect(candidates[2].name, 'php8.5-zip');
    });

    test('ignores lines that are not name - description pairs', () {
      const stdout = '''
php8.5-mbstring - MBSTRING module for PHP
WARNING: apt does not have a stable CLI interface.
''';
      expect(driver.parsePackageList(stdout, '8.5').length, equals(1));
    });

    test('drops a name that fails the safety check', () {
      const stdout = 'php8.5-a b; rm -rf / - evil\nphp8.5-curl - CURL module for PHP\n';
      final candidates = driver.parsePackageList(stdout, '8.5');
      expect(candidates.map((c) => c.name), equals(['php8.5-curl']));
    });
  });

  group('DebianPhpExtensionDriver.parseFileList', () {
    test('keeps only .so files whose parent is extensionDir', () {
      const stdout = '''
php8.5-mbstring: /usr/lib/php/20250925/mbstring.so
php8.5-mysql: /usr/lib/php/20250925/mysqli.so
php8.5-mysql: /usr/lib/php/20250925/mysqlnd.so
php8.5-mysql: /usr/lib/php/20250925/pdo_mysql.so
php8.5-common: /usr/lib/php/20250925/ctype.so
php8.5-common: /usr/lib/php/20250925/calendar.so
php8.5-dev: /usr/lib/php/20250925/build/phpize.m4
php8.5-common: /usr/share/doc/php8.5-common/changelog.gz
php8.5-fpm: /usr/bin/php-fpm8.5
''';
      final byPackage = driver.parseFileList(stdout, extDir);

      expect(byPackage['php8.5-mbstring'], equals(['mbstring']));
      expect(byPackage['php8.5-mysql'], equals(['mysqli', 'mysqlnd', 'pdo_mysql']));
      expect(byPackage['php8.5-common'], equals(['calendar', 'ctype']));
      // php8.5-dev ships files under extensionDir but no .so, and php8.5-fpm
      // ships none at all: neither is an extension package.
      expect(byPackage.containsKey('php8.5-dev'), isFalse);
      expect(byPackage.containsKey('php8.5-fpm'), isFalse);
    });

    test('ignores a .so that lives outside extensionDir', () {
      // /usr/lib/php/20250925 is extensionDir; a sibling ABI directory is not.
      const stdout = '''
php8.5-other: /usr/lib/php/20240924/other.so
php8.5-mbstring: /usr/lib/php/20250925/mbstring.so
''';
      final byPackage = driver.parseFileList(stdout, extDir);
      expect(byPackage.keys, equals(['php8.5-mbstring']));
    });

    test('a package whose name differs from its extension is still resolved', () {
      // Real sury data: php8.5-interbase ships pdo_firebird.so, php8.5-sybase
      // ships pdo_dblib.so. No prefix-stripping heuristic could find these.
      const stdout = '''
php8.5-interbase: /usr/lib/php/20250925/pdo_firebird.so
php8.5-sybase: /usr/lib/php/20250925/pdo_dblib.so
''';
      final byPackage = driver.parseFileList(stdout, extDir);
      expect(byPackage['php8.5-interbase'], equals(['pdo_firebird']));
      expect(byPackage['php8.5-sybase'], equals(['pdo_dblib']));
    });
  });

  group('combine', () {
    test('attaches extension names and drops non-extension packages', () {
      final packages = driver.parsePackageList('''
php8.5-mbstring - MBSTRING module for PHP
php8.5-fpm - server-side, HTML-embedded scripting language (FPM-CGI binary)
php8.5-common - documentation, examples and common module for PHP
''', '8.5');
      final files = driver.parseFileList('''
php8.5-mbstring: /usr/lib/php/20250925/mbstring.so
php8.5-common: /usr/lib/php/20250925/ctype.so
''', extDir);

      final combined = driver.combine(packages, files);

      expect(combined.map((c) => c.name), equals(['php8.5-mbstring', 'php8.5-common']));
      expect(combined[0].extensionNames, equals(['mbstring']));
      expect(combined[0].description, 'MBSTRING module for PHP');
      expect(combined[1].extensionNames, equals(['ctype']));
    });
  });

  group('DebianPhpExtensionDriver commands', () {
    test('discovers packages and file lists for the requested version', () {
      expect(
        driver.packageListCommands('8.5'),
        equals(['apt-cache search --names-only php8.5-']),
      );
      expect(
        driver.fileListCommands('8.5', const []),
        equals(["apt-file list -x '^php8.5-'"]),
      );
    });

    test('installs with apt-get install -y', () {
      expect(
        driver.installCommands(
          const PackageCandidate(name: 'php8.5-mbstring'),
          '8.5',
        ),
        equals(['apt-get install -y php8.5-mbstring']),
      );
    });

    test('enables and disables through phpenmod/phpdismod', () {
      expect(driver.iniStrategy, PhpIniStrategy.externalTool);
      expect(
        driver.enableCommands('8.5', 'mbstring'),
        equals(['phpenmod -v 8.5 -s fpm mbstring']),
      );
      expect(
        driver.disableCommands('8.5', 'mbstring'),
        equals(['phpdismod -v 8.5 -s fpm mbstring']),
      );
    });

    test('marks opcache and xdebug as zend extensions', () {
      expect(driver.isZendExtension('opcache'), isTrue);
      expect(driver.isZendExtension('xdebug'), isTrue);
      expect(driver.isZendExtension('mbstring'), isFalse);
    });

    test('every generated command passes PackageCommandValidator', () {
      for (final cmd in [
        ...driver.packageListCommands('8.5'),
        ...driver.fileListCommands('8.5', const []),
        ...driver.installCommands(const PackageCandidate(name: 'php8.5-mbstring'), '8.5'),
        ...driver.enableCommands('8.5', 'mbstring'),
        ...driver.disableCommands('8.5', 'mbstring'),
      ]) {
        expect(PackageCommandValidator.validate(cmd), isNull, reason: 'rejected: $cmd');
      }
    });
  });
}
