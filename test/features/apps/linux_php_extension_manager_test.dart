import 'dart:io';

import 'package:dev_stack/features/apps/data/linux_php_extension_driver.dart';
import 'package:dev_stack/features/apps/data/linux_php_extension_manager.dart';
import 'package:dev_stack/features/apps/data/linux_php_introspector.dart';
import 'package:dev_stack/features/apps/data/package_command_validator.dart';
import 'package:dev_stack/features/apps/data/php_extension_drivers/debian_php_extension_driver.dart';
import 'package:dev_stack/features/apps/data/php_extension_drivers/rhel_php_extension_driver.dart';
import 'package:flutter_test/flutter_test.dart';

/// A fake runProcess keyed on exact command strings.
///
/// The key is built from the **argv as the manager passes it**, which is after
/// [LinuxPhpExtensionDriver.splitCommand] has stripped the single quotes the
/// discovery commands carry. So `"apt-file list -x '^php8.5-'"` is stubbed as
/// `'apt-file list -x ^php8.5-'` — the pattern without quotes.
Future<ProcessResult> Function(String, List<String>) fakeRunner(
  Map<String, ({int exitCode, String stdout})> responses,
) {
  return (exe, args) async {
    final key = ([exe, ...args]).join(' ');
    final r = responses[key];
    if (r == null) {
      return ProcessResult(0, 127, '', 'not stubbed: $key');
    }
    return ProcessResult(0, r.exitCode, r.stdout, '');
  };
}

/// The discovery stub set every `applyToggle` test needs: `_enable` re-runs
/// discovery to find the owning package, so a test that stubs only `-m` gets
/// exit 127 from these three and never produces the install command.
Map<String, ({int exitCode, String stdout})> _debianDiscovery({
  String packages = 'php8.5-curl - CURL module for PHP\n',
  String files = 'php8.5-curl: /usr/lib/php/20250925/curl.so\n',
}) => {
  'apt-cache search --names-only php8.5-': (exitCode: 0, stdout: packages),
  'apt-file list -x ^php8.5-': (exitCode: 0, stdout: files),
};

const _debianInfo = '''
phpinfo()
PHP Version => 8.5.0

Scan this dir for additional .ini files => /etc/php/8.5/fpm/conf.d
Additional .ini files parsed => /etc/php/8.5/fpm/conf.d/20-mbstring.ini

extension_dir => /usr/lib/php/20250925 => /usr/lib/php/20250925
''';

const _debianModules = '''
[PHP Modules]
Core
mbstring
opcache
standard
''';

void main() {
  group('LinuxPhpExtensionManager.listExtensions (Debian)', () {
    test('merges package candidates with enabled modules incl. synthetic opcache', () async {
      final runProcess = fakeRunner({
        '/usr/sbin/php-fpm8.5 -i': (exitCode: 0, stdout: _debianInfo),
        '/usr/sbin/php-fpm8.5 -m': (exitCode: 0, stdout: _debianModules),
        'apt-cache search --names-only php8.5-': (
          exitCode: 0,
          stdout: 'php8.5-mbstring - MBSTRING module for PHP\nphp8.5-curl - CURL module for PHP\n',
        ),
        'apt-file list -x ^php8.5-': (
          exitCode: 0,
          stdout: 'php8.5-mbstring: /usr/lib/php/20250925/mbstring.so\n'
              'php8.5-curl: /usr/lib/php/20250925/curl.so\n',
        ),
      });
      final manager = LinuxPhpExtensionManager(
        introspector: LinuxPhpIntrospector(runProcess: runProcess),
        driver: DebianPhpExtensionDriver(),
        runProcess: runProcess,
        fileExists: (_) => true,
      );

      final exts = await manager.listExtensions(
        binaryPath: '/usr/sbin/php-fpm8.5',
        phpVersion: '8.5',
      );

      // `standard` is enabled and owned by no package, so it arrives from the
      // module side as a package-less (synthetic) entry — spec §3.1 step 4 and
      // the plan's Review Focus 2 ("expects it listed, not hidden").
      expect(
        exts.map((e) => e.name),
        equals(['curl', 'mbstring', 'opcache', 'standard']),
      );
      final mb = exts[1];
      expect(mb.isEnabled, isTrue);
      expect(mb.isInstalled, isTrue);
      expect(mb.packageName, 'php8.5-mbstring');
      expect(mb.description, 'MBSTRING module for PHP');
      // opcache is enabled, manageable, and must NOT render "Not installed".
      final op = exts[2];
      expect(op.isEnabled, isTrue);
      expect(op.isInstalled, isTrue);
      expect(op.packageName, isNull);
      expect(op.isZend, isTrue);
      expect(op.fileName, 'opcache.so');
    });

    test('marks a discovered-but-absent .so as not installed', () async {
      final runProcess = fakeRunner({
        '/usr/sbin/php-fpm8.5 -i': (exitCode: 0, stdout: _debianInfo),
        '/usr/sbin/php-fpm8.5 -m': (exitCode: 0, stdout: '[PHP Modules]\nCore\n'),
        'apt-cache search --names-only php8.5-': (
          exitCode: 0,
          stdout: 'php8.5-curl - CURL module for PHP\n',
        ),
        'apt-file list -x ^php8.5-': (
          exitCode: 0,
          stdout: 'php8.5-curl: /usr/lib/php/20250925/curl.so\n',
        ),
      });
      final manager = LinuxPhpExtensionManager(
        introspector: LinuxPhpIntrospector(runProcess: runProcess),
        driver: DebianPhpExtensionDriver(),
        runProcess: runProcess,
        fileExists: (_) => false,
      );

      final exts = await manager.listExtensions(
        binaryPath: '/usr/sbin/php-fpm8.5',
        phpVersion: '8.5',
      );

      expect(exts.length, equals(1));
      expect(exts.single.name, 'curl');
      expect(exts.single.isInstalled, isFalse);
      expect(exts.single.isEnabled, isFalse);
    });

    test('drops a package name that fails the safety regex', () async {
      final runProcess = fakeRunner({
        '/usr/sbin/php-fpm8.5 -i': (exitCode: 0, stdout: _debianInfo),
        '/usr/sbin/php-fpm8.5 -m': (exitCode: 0, stdout: '[PHP Modules]\nCore\n'),
        'apt-cache search --names-only php8.5-': (
          exitCode: 0,
          stdout: 'php8.5-evil; rm -rf / - boom\nphp8.5-curl - CURL module for PHP\n',
        ),
        'apt-file list -x ^php8.5-': (
          exitCode: 0,
          stdout: 'php8.5-curl: /usr/lib/php/20250925/curl.so\n',
        ),
      });
      final manager = LinuxPhpExtensionManager(
        introspector: LinuxPhpIntrospector(runProcess: runProcess),
        driver: DebianPhpExtensionDriver(),
        runProcess: runProcess,
        fileExists: (_) => true,
      );

      final exts = await manager.listExtensions(
        binaryPath: '/usr/sbin/php-fpm8.5',
        phpVersion: '8.5',
      );

      expect(exts.map((e) => e.name), equals(['curl']));
    });

    test('throws LinuxPhpDiscoveryUnavailable when apt-file is missing', () async {
      final runProcess = fakeRunner({
        '/usr/sbin/php-fpm8.5 -i': (exitCode: 0, stdout: _debianInfo),
        '/usr/sbin/php-fpm8.5 -m': (exitCode: 0, stdout: '[PHP Modules]\nCore\n'),
        'apt-cache search --names-only php8.5-': (
          exitCode: 0,
          stdout: 'php8.5-curl - CURL module for PHP\n',
        ),
        // exit 127 with empty stdout: apt-file is not installed.
        'apt-file list -x ^php8.5-': (exitCode: 127, stdout: ''),
      });
      final manager = LinuxPhpExtensionManager(
        introspector: LinuxPhpIntrospector(runProcess: runProcess),
        driver: DebianPhpExtensionDriver(),
        runProcess: runProcess,
        fileExists: (_) => true,
      );

      expect(
        () => manager.listExtensions(
          binaryPath: '/usr/sbin/php-fpm8.5',
          phpVersion: '8.5',
        ),
        throwsA(isA<LinuxPhpDiscoveryUnavailable>()),
      );
    });

    test('treats a ProcessException from a missing tool as discovery unavailable', () async {
      // This is how a missing tool actually surfaces on a real host: discovery
      // runs through Process.run (no shell), so Dart throws ProcessException
      // when the executable is absent — there is no exit 127 to inspect. If
      // this arm were missing, the exception would be swallowed by the generic
      // catch and the user would see a silently empty extension list.
      Future<ProcessResult> runProcess(String exe, List<String> args) async {
        final key = ([exe, ...args]).join(' ');
        if (key == '/usr/sbin/php-fpm8.5 -i') {
          return ProcessResult(0, 0, _debianInfo, '');
        }
        if (key == '/usr/sbin/php-fpm8.5 -m') {
          return ProcessResult(0, 0, '[PHP Modules]\nCore\n', '');
        }
        if (key == 'apt-cache search --names-only php8.5-') {
          return ProcessResult(0, 0, 'php8.5-curl - CURL module for PHP\n', '');
        }
        if (key == 'apt-file list -x ^php8.5-') {
          throw const ProcessException('apt-file', [], 'No such file or directory');
        }
        return ProcessResult(0, 127, '', 'not stubbed: $key');
      }

      final manager = LinuxPhpExtensionManager(
        introspector: LinuxPhpIntrospector(runProcess: runProcess),
        driver: DebianPhpExtensionDriver(),
        runProcess: runProcess,
        fileExists: (_) => true,
      );

      expect(
        () => manager.listExtensions(
          binaryPath: '/usr/sbin/php-fpm8.5',
          phpVersion: '8.5',
        ),
        throwsA(isA<LinuxPhpDiscoveryUnavailable>()),
      );
    });
  });

  group('LinuxPhpExtensionManager.listExtensions (RHEL)', () {
    test('resolves redis from php-pecl-redis6 through the dnf5 attributed file list', () async {
      const info = '''
phpinfo()
PHP Version => 8.5.0

Scan this dir for additional .ini files => /etc/php.d
Additional .ini files parsed => /etc/php.d/20-redis.ini

extension_dir => /usr/lib64/php/modules => /usr/lib64/php/modules
''';
      final runProcess = fakeRunner({
        '/usr/sbin/php-fpm -i': (exitCode: 0, stdout: info),
        '/usr/sbin/php-fpm -m': (
          exitCode: 0,
          stdout: '[PHP Modules]\nCore\nredis\n',
        ),
        'dnf repoquery --qf %{name}\\n php-* php85-php-*': (
          exitCode: 0,
          stdout: 'php-pecl-redis6\nphp-embedded\n',
        ),
        // dnf5 block form: the package name appears once, then bare paths.
        'dnf repoquery --qf %{name} %{files}\\n php-* php85-php-*': (
          exitCode: 0,
          stdout: 'php-pecl-redis6 /usr/lib64/php/modules/redis.so\n'
              'php-embedded /usr/lib64/libphp.so\n',
        ),
      });
      final manager = LinuxPhpExtensionManager(
        introspector: LinuxPhpIntrospector(runProcess: runProcess),
        driver: RhelPhpExtensionDriver(),
        runProcess: runProcess,
        fileExists: (path) => path.endsWith('/redis.so'),
      );

      final exts = await manager.listExtensions(
        binaryPath: '/usr/sbin/php-fpm',
        phpVersion: '8.5',
      );

      expect(exts.map((e) => e.name), equals(['redis']));
      expect(exts.single.packageName, 'php-pecl-redis6');
      expect(exts.single.isEnabled, isTrue);
    });

    test('falls back to the dnf4 bare file list and marks the owner unknown', () async {
      // On dnf4 the attributed form does not fail — it prints the literal
      // `%{files}` and exits 0 — so the manager must reject the empty parse and
      // try the `-l` form. That form carries no package, so the extension is
      // listed with a null package and its .so decides "installed".
      const info = '''
phpinfo()
PHP Version => 8.5.0

Scan this dir for additional .ini files => /etc/php.d

extension_dir => /usr/lib64/php/modules => /usr/lib64/php/modules
''';
      final runProcess = fakeRunner({
        '/usr/sbin/php-fpm -i': (exitCode: 0, stdout: info),
        '/usr/sbin/php-fpm -m': (
          exitCode: 0,
          stdout: '[PHP Modules]\nCore\n',
        ),
        'dnf repoquery --qf %{name}\\n php-* php85-php-*': (
          exitCode: 0,
          stdout: 'php-pecl-imagick-im7\n',
        ),
        'dnf repoquery --qf %{name} %{files}\\n php-* php85-php-*': (
          exitCode: 0,
          stdout: 'php-pecl-imagick-im7 %{files}\n',
        ),
        'dnf repoquery -l php-* php85-php-*': (
          exitCode: 0,
          stdout: '/usr/lib64/php/modules/imagick.so\n'
              '/usr/lib64/libphp.so\n',
        ),
      });
      final manager = LinuxPhpExtensionManager(
        introspector: LinuxPhpIntrospector(runProcess: runProcess),
        driver: RhelPhpExtensionDriver(),
        runProcess: runProcess,
        fileExists: (_) => false,
      );

      final exts = await manager.listExtensions(
        binaryPath: '/usr/sbin/php-fpm',
        phpVersion: '8.5',
      );

      expect(exts.map((e) => e.name), equals(['imagick']));
      expect(exts.single.packageName, isNull);
      expect(exts.single.isInstalled, isFalse);
      expect(exts.single.isEnabled, isFalse);
    });
  });

  group('LinuxPhpExtensionManager.applyToggle', () {
    test('enable installs then enables under one elevation with a reload', () async {
      final elevated = <List<String>>[];
      var reloadedPid = -1;
      final runProcess = fakeRunner({
        '/usr/sbin/php-fpm8.5 -i': (exitCode: 0, stdout: _debianInfo),
        '/usr/sbin/php-fpm8.5 -m': (
          exitCode: 0,
          stdout: '[PHP Modules]\nCore\ncurl\n',
        ),
        ..._debianDiscovery(),
      });
      final manager = LinuxPhpExtensionManager(
        introspector: LinuxPhpIntrospector(runProcess: runProcess),
        driver: DebianPhpExtensionDriver(),
        runProcess: runProcess,
        runElevated: ({required commands, required logInfo, required logError}) async {
          elevated.add(commands);
          return ProcessResult(0, 0, '', '');
        },
        reloader: (pid) async {
          reloadedPid = pid;
        },
      );

      final message = await manager.applyToggle(
        binaryPath: '/usr/sbin/php-fpm8.5',
        phpVersion: '8.5',
        scanDir: '/etc/php/8.5/fpm/conf.d',
        parsedIniFiles: const [],
        extName: 'curl',
        enable: true,
        servicePid: 4242,
      );

      expect(elevated.length, equals(1));
      expect(
        elevated.single,
        equals([
          'apt-get install -y php8.5-curl',
          'phpenmod -v 8.5 -s fpm curl',
        ]),
      );
      expect(reloadedPid, equals(4242));
      expect(message, contains('curl'));
    });

    test('enable skips install when the .so is already present', () async {
      final elevated = <List<String>>[];
      final runProcess = fakeRunner({
        '/usr/sbin/php-fpm8.5 -i': (exitCode: 0, stdout: _debianInfo),
        '/usr/sbin/php-fpm8.5 -m': (
          exitCode: 0,
          stdout: '[PHP Modules]\nCore\ncurl\n',
        ),
        ..._debianDiscovery(),
      });
      final manager = LinuxPhpExtensionManager(
        introspector: LinuxPhpIntrospector(runProcess: runProcess),
        driver: DebianPhpExtensionDriver(),
        runProcess: runProcess,
        runElevated: ({required commands, required logInfo, required logError}) async {
          elevated.add(commands);
          return ProcessResult(0, 0, '', '');
        },
        reloader: (_) async {},
        fileExists: (_) => true,
      );

      await manager.applyToggle(
        binaryPath: '/usr/sbin/php-fpm8.5',
        phpVersion: '8.5',
        scanDir: '/etc/php/8.5/fpm/conf.d',
        parsedIniFiles: const [],
        extName: 'curl',
        enable: true,
        servicePid: null,
      );

      expect(elevated.single, equals(['phpenmod -v 8.5 -s fpm curl']));
    });

    test('enable of opcache writes opcache.enable=1 through tee, not zend_extension=', () async {
      final elevated = <List<String>>[];
      final runProcess = fakeRunner({
        '/usr/sbin/php-fpm -i': (
          exitCode: 0,
          stdout: 'Scan this dir for additional .ini files => /etc/php.d\n'
              'extension_dir => /usr/lib64/php/modules => /usr/lib64/php/modules\n',
        ),
        '/usr/sbin/php-fpm -m': (
          exitCode: 0,
          stdout: '[PHP Modules]\nCore\nopcache\n',
        ),
      });
      final manager = LinuxPhpExtensionManager(
        introspector: LinuxPhpIntrospector(runProcess: runProcess),
        driver: RhelPhpExtensionDriver(),
        runProcess: runProcess,
        runElevated: ({required commands, required logInfo, required logError}) async {
          elevated.add(commands);
          return ProcessResult(0, 0, '', '');
        },
        reloader: (_) async {},
      );

      await manager.applyToggle(
        binaryPath: '/usr/sbin/php-fpm',
        phpVersion: '8.5',
        scanDir: '/etc/php.d',
        parsedIniFiles: const [],
        extName: 'opcache',
        enable: true,
        servicePid: null,
      );

      expect(elevated.length, equals(1));
      expect(elevated.single.length, equals(1));
      expect(
        elevated.single.single,
        equals("echo 'opcache.enable=1' | tee /etc/php.d/99-ponta-opcache.ini"),
      );
      expect(elevated.single.single, isNot(contains('zend_extension=opcache')));
      // The command must survive the validator unchanged — `>` is banned, and
      // an unquoted tee target is what makes the widened regex enforceable.
      expect(PackageCommandValidator.validate(elevated.single.single), isNull);
    });

    test('enable of a normal extension writes extension= through tee', () async {
      final elevated = <List<String>>[];
      final runProcess = fakeRunner({
        '/usr/sbin/php-fpm -i': (
          exitCode: 0,
          stdout: 'Scan this dir for additional .ini files => /etc/php.d\n'
              'extension_dir => /usr/lib64/php/modules => /usr/lib64/php/modules\n',
        ),
        '/usr/sbin/php-fpm -m': (
          exitCode: 0,
          stdout: '[PHP Modules]\nCore\nredis\n',
        ),
        'dnf repoquery --qf %{name}\\n php-* php85-php-*': (
          exitCode: 0,
          stdout: 'php-pecl-redis6\n',
        ),
        'dnf repoquery --qf %{name} %{files}\\n php-* php85-php-*': (
          exitCode: 0,
          stdout: 'php-pecl-redis6 /usr/lib64/php/modules/redis.so\n',
        ),
      });
      final manager = LinuxPhpExtensionManager(
        introspector: LinuxPhpIntrospector(runProcess: runProcess),
        driver: RhelPhpExtensionDriver(),
        runProcess: runProcess,
        runElevated: ({required commands, required logInfo, required logError}) async {
          elevated.add(commands);
          return ProcessResult(0, 0, '', '');
        },
        reloader: (_) async {},
        fileExists: (_) => true,
      );

      await manager.applyToggle(
        binaryPath: '/usr/sbin/php-fpm',
        phpVersion: '8.5',
        scanDir: '/etc/php.d',
        parsedIniFiles: const [],
        extName: 'redis',
        enable: true,
        servicePid: null,
      );

      expect(
        elevated.single,
        equals(["echo 'extension=redis' | tee /etc/php.d/99-ponta-redis.ini"]),
      );
    });

    test('enable resolves an unknown owner with dnf -f then installs it', () async {
      // dnf4 lists extensions without a package (bare `-l`). At enable time the
      // manager must name the owner with `-f <path>` and install that package,
      // in the same single elevation as the enable step.
      final elevated = <List<String>>[];
      final runProcess = fakeRunner({
        '/usr/sbin/php-fpm -i': (
          exitCode: 0,
          stdout: 'Scan this dir for additional .ini files => /etc/php.d\n'
              'extension_dir => /usr/lib64/php/modules => /usr/lib64/php/modules\n',
        ),
        '/usr/sbin/php-fpm -m': (
          exitCode: 0,
          stdout: '[PHP Modules]\nCore\nimagick\n',
        ),
        'dnf repoquery --qf %{name}\\n php-* php85-php-*': (
          exitCode: 0,
          stdout: 'php-pecl-imagick-im7\n',
        ),
        'dnf repoquery --qf %{name} %{files}\\n php-* php85-php-*': (
          exitCode: 0,
          stdout: 'php-pecl-imagick-im7 %{files}\n',
        ),
        'dnf repoquery -l php-* php85-php-*': (
          exitCode: 0,
          stdout: '/usr/lib64/php/modules/imagick.so\n',
        ),
        'dnf repoquery --qf %{name}\\n -f /usr/lib64/php/modules/imagick.so': (
          exitCode: 0,
          stdout: 'php-pecl-imagick-im7\n',
        ),
      });
      final manager = LinuxPhpExtensionManager(
        introspector: LinuxPhpIntrospector(runProcess: runProcess),
        driver: RhelPhpExtensionDriver(),
        runProcess: runProcess,
        runElevated: ({required commands, required logInfo, required logError}) async {
          elevated.add(commands);
          return ProcessResult(0, 0, '', '');
        },
        reloader: (_) async {},
        fileExists: (_) => false,
      );

      await manager.applyToggle(
        binaryPath: '/usr/sbin/php-fpm',
        phpVersion: '8.5',
        scanDir: '/etc/php.d',
        parsedIniFiles: const [],
        extName: 'imagick',
        enable: true,
        servicePid: null,
      );

      expect(
        elevated.single,
        equals([
          'dnf install -y php-pecl-imagick-im7',
          "echo 'extension=imagick' | tee /etc/php.d/99-ponta-imagick.ini",
        ]),
      );
    });

    test('disable comments out the loader line in every parsed ini, incl. ours', () async {
      final elevated = <List<String>>[];
      final runProcess = fakeRunner({
        '/usr/sbin/php-fpm -m': (
          exitCode: 0,
          stdout: '[PHP Modules]\nCore\n',
        ),
      });
      final manager = LinuxPhpExtensionManager(
        introspector: LinuxPhpIntrospector(runProcess: runProcess),
        driver: RhelPhpExtensionDriver(),
        runProcess: runProcess,
        runElevated: ({required commands, required logInfo, required logError}) async {
          elevated.add(commands);
          return ProcessResult(0, 0, '', '');
        },
        reloader: (_) async {},
      );

      await manager.applyToggle(
        binaryPath: '/usr/sbin/php-fpm',
        phpVersion: '8.5',
        scanDir: '/etc/php.d',
        parsedIniFiles: const [
          '/etc/php.d/20-redis.ini',
          '/etc/php.d/99-ponta-redis.ini',
        ],
        extName: 'redis',
        enable: false,
        servicePid: null,
      );

      expect(elevated.length, equals(1));
      expect(elevated.single.length, equals(2));
      // Our own file is in the parsed list, so commenting it out is the whole
      // disable — no `rm` (which is not on the validator's allowlist).
      for (final cmd in elevated.single) {
        expect(cmd, startsWith('sed -E -i '));
        expect(cmd, contains(r'\x3b'));
        expect(PackageCommandValidator.validate(cmd), isNull, reason: cmd);
      }
      expect(elevated.single[0], contains('/etc/php.d/20-redis.ini'));
      expect(elevated.single[1], contains('/etc/php.d/99-ponta-redis.ini'));
      // The pattern is anchored on the full name, so it cannot match a longer
      // name that merely starts with it (`pdo` must not knock out `pdo_mysql`).
      expect(elevated.single[0], contains(r'redis(\.so)?"?\s*$'));
    });

    test('disable refuses to sed a file outside the scan dir or with an unsafe name', () async {
      // The parsed-ini list is attacker-reachable (it is whatever `php-fpm -i`
      // printed), and the validator does not constrain `sed`'s target — only
      // its leading binary. So the manager must gate the path itself: a file
      // outside `scanDir`, or one whose name would break the single-quoted
      // shell word (a `'` in the basename injects extra `sed -e` expressions
      // that contain none of the validator's forbidden substrings), must be
      // skipped rather than rewritten.
      final elevated = <List<String>>[];
      final runProcess = fakeRunner({
        '/usr/sbin/php-fpm -m': (
          exitCode: 0,
          stdout: '[PHP Modules]\nCore\nredis\n',
        ),
      });
      final manager = LinuxPhpExtensionManager(
        introspector: LinuxPhpIntrospector(runProcess: runProcess),
        driver: RhelPhpExtensionDriver(),
        runProcess: runProcess,
        runElevated: ({required commands, required logInfo, required logError}) async {
          elevated.add(commands);
          return ProcessResult(0, 0, '', '');
        },
        reloader: (_) async {},
      );

      await manager.applyToggle(
        binaryPath: '/usr/sbin/php-fpm',
        phpVersion: '8.5',
        scanDir: '/etc/php.d',
        parsedIniFiles: const [
          '/etc/php.d/20-redis.ini', // legitimate: kept
          '/etc/shadow', // outside scanDir: dropped
          '/etc/php.d/../../shadow', // traversal: dropped
          "/etc/php.d/x.ini' -e 's,.*,PWNED,w /tmp/p' -e '", // injection: dropped
          '/etc/php.d/sub/nested.ini', // not a plain child: dropped
          '/etc/php.d/UPPER.ini', // fails isSafeName: dropped
        ],
        extName: 'redis',
        enable: false,
        servicePid: null,
      );

      expect(elevated.length, equals(1));
      expect(
        elevated.single.length,
        equals(1),
        reason: 'only /etc/php.d/20-redis.ini may be rewritten',
      );
      expect(elevated.single.single, contains('/etc/php.d/20-redis.ini'));
      for (final bad in ['/etc/shadow', 'PWNED', 'nested.ini', 'UPPER.ini']) {
        expect(elevated.single.single, isNot(contains(bad)));
      }
    });

    test('enable and disable work on Remi SCL layout (/etc/opt/remi/php85/php.d)', () async {
      final elevated = <List<String>>[];
      const bin = '/opt/remi/php85/root/usr/sbin/php-fpm';
      const scanDir = '/etc/opt/remi/php85/php.d';
      const extDir = '/opt/remi/php85/root/usr/lib64/php/modules';
      final runProcess = fakeRunner({
        '$bin -i': (
          exitCode: 0,
          stdout: 'Scan this dir for additional .ini files => $scanDir\n'
              'extension_dir => $extDir => $extDir\n',
        ),
        '$bin -m': (
          exitCode: 0,
          stdout: '[PHP Modules]\nCore\nredis\n',
        ),
        'dnf repoquery --qf %{name}\\n php-* php85-php-*': (
          exitCode: 0,
          stdout: 'php85-php-pecl-redis6\n',
        ),
        'dnf repoquery --qf %{name} %{files}\\n php-* php85-php-*': (
          exitCode: 0,
          stdout: 'php85-php-pecl-redis6 $extDir/redis.so\n',
        ),
      });
      final manager = LinuxPhpExtensionManager(
        introspector: LinuxPhpIntrospector(runProcess: runProcess),
        driver: RhelPhpExtensionDriver(),
        runProcess: runProcess,
        runElevated: ({required commands, required logInfo, required logError}) async {
          elevated.add(commands);
          return ProcessResult(0, 0, '', '');
        },
        reloader: (_) async {},
        fileExists: (_) => true,
      );

      await manager.applyToggle(
        binaryPath: bin,
        phpVersion: '8.5',
        scanDir: scanDir,
        parsedIniFiles: const [],
        extName: 'redis',
        enable: true,
        servicePid: null,
      );

      expect(
        elevated.single,
        equals(["echo 'extension=redis' | tee $scanDir/99-ponta-redis.ini"]),
      );
      expect(PackageCommandValidator.validate(elevated.single.single), isNull);
    });

    test('the disable pattern is name-anchored so pdo cannot disable pdo_mysql', () {
      final driver = RhelPhpExtensionDriver();
      final pattern = driver.disableIniPattern('pdo');
      final re = RegExp(pattern);
      expect(re.hasMatch('extension=pdo.so'), isTrue);
      expect(re.hasMatch('zend_extension="pdo.so"'), isTrue);
      expect(re.hasMatch('extension=/usr/lib64/php/modules/pdo.so'), isTrue);
      expect(re.hasMatch('extension=pdo_mysql.so'), isFalse);
      expect(re.hasMatch('extension=pdo_pgsql.so'), isFalse);
    });

    test('disable of opcache uses the opcache.enable pattern, not the loader one', () async {
      final elevated = <List<String>>[];
      final runProcess = fakeRunner({
        '/usr/sbin/php-fpm -m': (
          exitCode: 0,
          stdout: '[PHP Modules]\nCore\nopcache\n',
        ),
      });
      final manager = LinuxPhpExtensionManager(
        introspector: LinuxPhpIntrospector(runProcess: runProcess),
        driver: RhelPhpExtensionDriver(),
        runProcess: runProcess,
        runElevated: ({required commands, required logInfo, required logError}) async {
          elevated.add(commands);
          return ProcessResult(0, 0, '', '');
        },
        reloader: (_) async {},
      );

      await manager.applyToggle(
        binaryPath: '/usr/sbin/php-fpm',
        phpVersion: '8.5',
        scanDir: '/etc/php.d',
        parsedIniFiles: const ['/etc/php.d/10-opcache.ini'],
        extName: 'opcache',
        enable: false,
        servicePid: null,
      );

      expect(elevated.single.single, contains('opcache'));
      expect(elevated.single.single, contains(r'opcache\.enable'));
      expect(elevated.single.single, isNot(contains('zend_extension')));
    });

    test('reports restart-needed instead of failing when the master is not running', () async {
      final runProcess = fakeRunner({
        '/usr/sbin/php-fpm8.5 -i': (exitCode: 0, stdout: _debianInfo),
        '/usr/sbin/php-fpm8.5 -m': (
          exitCode: 0,
          stdout: '[PHP Modules]\nCore\ncurl\n',
        ),
        ..._debianDiscovery(),
      });
      final manager = LinuxPhpExtensionManager(
        introspector: LinuxPhpIntrospector(runProcess: runProcess),
        driver: DebianPhpExtensionDriver(),
        runProcess: runProcess,
        runElevated: ({required commands, required logInfo, required logError}) async {
          return ProcessResult(0, 0, '', '');
        },
        reloader: (_) async {
          throw const ProcessException('kill', ['-USR2']);
        },
        fileExists: (_) => true,
      );

      final message = await manager.applyToggle(
        binaryPath: '/usr/sbin/php-fpm8.5',
        phpVersion: '8.5',
        scanDir: '/etc/php/8.5/fpm/conf.d',
        parsedIniFiles: const [],
        extName: 'curl',
        enable: true,
        servicePid: 4242,
      );

      expect(message.toLowerCase(), contains('restart'));
    });

    test('names the missing discovery tool instead of a misleading load failure', () async {
      // The .so is absent and discovery cannot say which package would provide
      // it: the user must be told to install `apt-file`, not that the extension
      // "did not load".
      final runProcess = fakeRunner({
        '/usr/sbin/php-fpm8.5 -i': (exitCode: 0, stdout: _debianInfo),
        '/usr/sbin/php-fpm8.5 -m': (
          exitCode: 0,
          stdout: '[PHP Modules]\nCore\n',
        ),
        // apt-file is not installed: exit 127.
        'apt-file list -x ^php8.5-': (exitCode: 127, stdout: ''),
        'apt-cache search --names-only php8.5-': (
          exitCode: 0,
          stdout: 'php8.5-curl - CURL module for PHP\n',
        ),
      });
      final manager = LinuxPhpExtensionManager(
        introspector: LinuxPhpIntrospector(runProcess: runProcess),
        driver: DebianPhpExtensionDriver(),
        runProcess: runProcess,
        runElevated: ({required commands, required logInfo, required logError}) async {
          fail('must not elevate when discovery is unavailable');
        },
        reloader: (_) async {},
        fileExists: (_) => false,
      );

      expect(
        () => manager.applyToggle(
          binaryPath: '/usr/sbin/php-fpm8.5',
          phpVersion: '8.5',
          scanDir: '/etc/php/8.5/fpm/conf.d',
          parsedIniFiles: const [],
          extName: 'curl',
          enable: true,
          servicePid: null,
        ),
        throwsA(isA<LinuxPhpDiscoveryUnavailable>()),
      );
    });

    test('throws rather than reporting success when the module stays absent', () async {
      final runProcess = fakeRunner({
        '/usr/sbin/php-fpm8.5 -i': (exitCode: 0, stdout: _debianInfo),
        '/usr/sbin/php-fpm8.5 -m': (
          exitCode: 0,
          stdout: '[PHP Modules]\nCore\n',
        ),
        ..._debianDiscovery(),
      });
      final manager = LinuxPhpExtensionManager(
        introspector: LinuxPhpIntrospector(runProcess: runProcess),
        driver: DebianPhpExtensionDriver(),
        runProcess: runProcess,
        runElevated: ({required commands, required logInfo, required logError}) async {
          return ProcessResult(0, 0, 'some log', '');
        },
        reloader: (_) async {},
        fileExists: (_) => true,
      );

      expect(
        () => manager.applyToggle(
          binaryPath: '/usr/sbin/php-fpm8.5',
          phpVersion: '8.5',
          scanDir: '/etc/php/8.5/fpm/conf.d',
          parsedIniFiles: const [],
          extName: 'curl',
          enable: true,
          servicePid: null,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}
