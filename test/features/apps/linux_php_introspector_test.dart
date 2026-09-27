import 'dart:io';

import 'package:dev_stack/features/apps/data/linux_php_introspector.dart';
import 'package:flutter_test/flutter_test.dart';

const _phpInfoFixture = '''
phpinfo()
PHP Version => 8.2.29

Configuration File (php.ini) Path => /etc/php/8.2/fpm
Loaded Configuration File => /etc/php/8.2/fpm/php.ini
Scan this dir for additional .ini files => /etc/php/8.2/fpm/conf.d
Additional .ini files parsed => /etc/php/8.2/fpm/conf.d/10-mysqlnd.ini,
/etc/php/8.2/fpm/conf.d/10-opcache.ini,
/etc/php/8.2/fpm/conf.d/20-mbstring.ini

extension_dir => /usr/lib/php/20220829 => /usr/lib/php/20220829
''';

const _phpInfoNoIniFixture = '''
phpinfo()
PHP Version => 8.2.29

Configuration File (php.ini) Path => /etc/php/8.2/fpm
Loaded Configuration File => (none)
Scan this dir for additional .ini files => (none)
Additional .ini files parsed => (none)

extension_dir => /usr/lib/php/20220829 => /usr/lib/php/20220829
''';

const _modulesFixture = '''
[PHP Modules]
Core
ctype
curl
date
json
mbstring
mysqli
opcache
pcre
standard
tokenizer

[Zend Modules]
Zend OPcache
''';

void main() {
  group('LinuxPhpIntrospector.readInfo', () {
    test('parses scan dir, extension dir, ini path and scanned files', () async {
      final calls = <({String exec, List<String> args})>[];
      final introspector = LinuxPhpIntrospector(
        runProcess: (exec, args) async {
          calls.add((exec: exec, args: args));
          return ProcessResult(1, 0, _phpInfoFixture, '');
        },
      );

      final info = await introspector.readInfo('/usr/sbin/php-fpm8.2');

      expect(calls.single.exec, '/usr/sbin/php-fpm8.2');
      expect(calls.single.args, equals(['-i']));
      expect(info.scanDir, '/etc/php/8.2/fpm/conf.d');
      expect(info.extensionDir, '/usr/lib/php/20220829');
      expect(info.iniPath, '/etc/php/8.2/fpm/php.ini');
      expect(info.scannedIniFiles, equals([
        '/etc/php/8.2/fpm/conf.d/10-mysqlnd.ini',
        '/etc/php/8.2/fpm/conf.d/10-opcache.ini',
        '/etc/php/8.2/fpm/conf.d/20-mbstring.ini',
      ]));
    });

    test('maps "(none)" to null instead of the literal string', () async {
      final introspector = LinuxPhpIntrospector(
        runProcess: (exec, args) async => ProcessResult(1, 0, _phpInfoNoIniFixture, ''),
      );

      final info = await introspector.readInfo('/usr/sbin/php-fpm8.2');

      expect(info.scanDir, isNull);
      expect(info.iniPath, isNull);
      expect(info.scannedIniFiles, isEmpty);
      // extension_dir is always present, even when no ini was loaded.
      expect(info.extensionDir, '/usr/lib/php/20220829');
    });

    test('returns empty info when the binary cannot be executed', () async {
      final introspector = LinuxPhpIntrospector(
        runProcess: (exec, args) async => throw const ProcessException('php-fpm', [], 'No such file'),
      );

      final info = await introspector.readInfo('/nonexistent/php-fpm');

      expect(info.scanDir, isNull);
      expect(info.extensionDir, isNull);
      expect(info.iniPath, isNull);
      expect(info.scannedIniFiles, isEmpty);
    });

    test('returns empty info on a non-zero exit code', () async {
      final introspector = LinuxPhpIntrospector(
        runProcess: (exec, args) async => ProcessResult(1, 127, '', 'command not found'),
      );

      final info = await introspector.readInfo('/usr/sbin/php-fpm8.2');

      expect(info.scanDir, isNull);
      expect(info.extensionDir, isNull);
    });
  });

  group('LinuxPhpIntrospector.readModules', () {
    test('parses the [PHP Modules] and [Zend Modules] sections', () async {
      final calls = <({String exec, List<String> args})>[];
      final introspector = LinuxPhpIntrospector(
        runProcess: (exec, args) async {
          calls.add((exec: exec, args: args));
          return ProcessResult(1, 0, _modulesFixture, '');
        },
      );

      final modules = await introspector.readModules('/usr/sbin/php-fpm8.2');

      expect(calls.single.args, equals(['-m']));
      expect(modules, contains('mbstring'));
      expect(modules, contains('curl'));
      expect(modules, contains('opcache'));
      // Section headers and blank lines are not module names.
      expect(modules, isNot(contains('[PHP Modules]')));
      expect(modules, isNot(contains('')));
      expect(modules.length, equals(12));
    });

    test('returns an empty set when the binary cannot be executed', () async {
      final introspector = LinuxPhpIntrospector(
        runProcess: (exec, args) async => throw const ProcessException('php-fpm', [], 'No such file'),
      );

      expect(await introspector.readModules('/nonexistent/php-fpm'), isEmpty);
    });
  });
}
