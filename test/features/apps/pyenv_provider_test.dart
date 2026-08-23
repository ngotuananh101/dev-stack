import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dev_stack/features/apps/data/pyenv_provider.dart';

void main() {
  group('Pyenv Environment Builder', () {
    test('builds Linux environment with PYENV_ROOT and PATH prepend', () {
      final env = PyenvNotifier.buildPyenvEnvironment(
        installPath: '/home/user/.ponta/apps/pyenv',
        isWindows: false,
        currentEnv: {'PATH': '/usr/local/bin:/usr/bin'},
      );

      expect(env['PYENV_ROOT'], equals('/home/user/.ponta/apps/pyenv'));
      expect(
        env['PATH'],
        equals(
          '/home/user/.ponta/apps/pyenv/bin:/home/user/.ponta/apps/pyenv/shims:/usr/local/bin:/usr/bin',
        ),
      );
    });

    test('builds Windows environment with pyenv-win directory', () {
      final env = PyenvNotifier.buildPyenvEnvironment(
        installPath: r'C:\Ponta\apps\pyenv',
        isWindows: true,
        currentEnv: {'Path': r'C:\Windows\System32'},
      );

      expect(env['PYENV'], equals(r'C:\Ponta\apps\pyenv\pyenv-win'));
      expect(env['PYENV_ROOT'], equals(r'C:\Ponta\apps\pyenv\pyenv-win'));
      expect(
        env['Path'],
        contains(r'C:\Ponta\apps\pyenv\pyenv-win\bin'),
      );
    });
  });

  group('Pyenv Executable Resolution', () {
    late Directory tmpDir;

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('pyenv_test_');
    });

    tearDown(() {
      if (tmpDir.existsSync()) {
        tmpDir.deleteSync(recursive: true);
      }
    });

    test('prefers libexec/pyenv on Linux if present', () {
      final libexecDir = Directory('${tmpDir.path}/libexec')..createSync(recursive: true);
      File('${libexecDir.path}/pyenv').writeAsStringSync('#!/bin/sh\n');

      final resolved = PyenvNotifier.resolvePyenvExecutable(
        installPath: tmpDir.path,
        isWindows: false,
      );

      expect(resolved, contains('libexec/pyenv'));
    });

    test('resolves windows bat path on Windows', () {
      final resolved = PyenvNotifier.resolvePyenvExecutable(
        installPath: r'C:\Ponta\apps\pyenv',
        isWindows: true,
      );

      expect(resolved, contains(r'pyenv-win\bin\pyenv.bat'));
    });
  });

  group('Pyenv Installable Versions Parser', () {
    test('parses Linux pyenv install -l output with indentation and headers', () {
      const mockLinuxOutput = '''
Available versions:
  2.7.18
  3.10.14
  3.10.16
  3.11.8
  3.11.11
  3.12.3
  3.12.9
  3.13.0
  3.13.2
  activepython-2.7.14
  anaconda3-2024.02-1
  cpython-3.12.3
  pypy3.10-7.3.16
  stackless-3.7.5
''';

      final versions = PyenvNotifier.parseInstallableVersions(mockLinuxOutput);

      // Should only keep standard CPython versions, latest patch per line, sorted descending
      expect(versions, equals(['3.13.2', '3.12.9', '3.11.11', '3.10.16', '2.7.18']));
    });

    test('parses Windows pyenv-win install -l output', () {
      const mockWindowsOutput = '''
:: [Info] ::  Mirror: https://www.python.org/ftp/python
2.7.18
3.11.8
3.11.11
3.12.9
''';

      final versions = PyenvNotifier.parseInstallableVersions(mockWindowsOutput);
      expect(versions, equals(['3.12.9', '3.11.11', '2.7.18']));
    });
  });

  group('Pyenv Installed Versions Parser', () {
    test('parses versions output and ignores system indicator', () {
      const mockLinuxVersions = '''
* system (set by /home/user/.ponta/apps/pyenv/version)
  3.11.11
  3.12.9
''';

      final installed = PyenvNotifier.parseInstalledVersions(mockLinuxVersions);
      expect(installed, equals(['3.11.11', '3.12.9']));
    });

    test('handles empty versions output', () {
      const mockEmpty = '* system\n';
      final installed = PyenvNotifier.parseInstalledVersions(mockEmpty);
      expect(installed, isEmpty);
    });
  });
}
