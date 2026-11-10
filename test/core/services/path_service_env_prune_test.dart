import 'dart:io';

import 'package:dev_stack/core/services/path_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Removing a variable Ponta never set would delete the user's own choice: a
/// system JDK's `JAVA_HOME` or a hand-written `GOROOT`. These tests pin the
/// rule that removal is scoped to the value Ponta wrote.
void main() {
  group('PathService.removeUserEnvVarValue', () {
    late Directory home;

    setUp(() {
      home = Directory.systemTemp.createTempSync('env_prune_test_');
    });

    tearDown(() {
      if (home.existsSync()) home.deleteSync(recursive: true);
    });

    Future<List<String>> writeProfile(String name, List<String> lines) async {
      final file = File(p.join(home.path, name));
      await file.writeAsString(lines.join('\n'));
      return file.readAsLines();
    }

    test('removes the export line Ponta wrote', () async {
      final lines = await writeProfile('.bashrc', [
        'alias ll="ls -la"',
        'export JAVA_HOME="/home/u/.ponta/apps/java/21.0.13"',
        r'export PATH="$HOME/.ponta/bin:$PATH"',
      ]);

      final removed = PathService.pruneEnvVarLines(
        lines,
        'JAVA_HOME',
        '/home/u/.ponta/apps/java/21.0.13',
      );

      expect(removed, [
        'alias ll="ls -la"',
        r'export PATH="$HOME/.ponta/bin:$PATH"',
      ]);
    });

    test('keeps a value the user set themselves', () async {
      final lines = await writeProfile('.bashrc', [
        'export JAVA_HOME="/usr/lib/jvm/temurin-21"',
      ]);

      final removed = PathService.pruneEnvVarLines(
        lines,
        'JAVA_HOME',
        '/home/u/.ponta/apps/java/21.0.13',
      );

      expect(removed, lines, reason: 'the value is not the one Ponta wrote');
    });

    test('leaves other variables that share the prefix alone', () async {
      final lines = await writeProfile('.bashrc', [
        'export JAVA_HOME_OLD="/home/u/.ponta/apps/java/17.0.21"',
        'export JAVA_HOME="/home/u/.ponta/apps/java/21.0.13"',
      ]);

      final removed = PathService.pruneEnvVarLines(
        lines,
        'JAVA_HOME',
        '/home/u/.ponta/apps/java/21.0.13',
      );

      expect(removed, [
        'export JAVA_HOME_OLD="/home/u/.ponta/apps/java/17.0.21"',
      ]);
    });

    test('matches quoted and unquoted spellings', () async {
      for (final line in [
        'export GOROOT="/opt/ponta/apps/go/1.27.3"',
        "export GOROOT='/opt/ponta/apps/go/1.27.3'",
        'export GOROOT=/opt/ponta/apps/go/1.27.3',
      ]) {
        expect(
          PathService.pruneEnvVarLines([line], 'GOROOT', '/opt/ponta/apps/go/1.27.3'),
          isEmpty,
          reason: 'could not remove: $line',
        );
      }
    });

    test('keeps commented-out history', () async {
      final lines = [
        '# export GOROOT="/opt/ponta/apps/go/1.27.3"',
        'export GOROOT="/opt/ponta/apps/go/1.27.3"',
      ];

      expect(
        PathService.pruneEnvVarLines(
          lines,
          'GOROOT',
          '/opt/ponta/apps/go/1.27.3',
        ),
        ['# export GOROOT="/opt/ponta/apps/go/1.27.3"'],
      );
    });
  });

  group('AppInstallerService cleanup on Windows', () {
    test('only clears the variable when it still points at the install', () async {
      // Documented by the value-scoped Windows command: the comparison happens
      // in PowerShell so a `JAVA_HOME` the user set is never overwritten.
      final cmd = PathService.windowsRemoveUserEnvVarValueCommand(
        'JAVA_HOME',
        r'C:\Ponta\apps\java\21.0.13',
      );

      expect(cmd.environment['DEVSTACK_ENVVAR'], equals('JAVA_HOME'));
      expect(
        cmd.environment['DEVSTACK_SETVALUE'],
        equals(r'C:\Ponta\apps\java\21.0.13'),
      );
      expect(
        cmd.arguments.join(' '),
        contains(r'if ($current -eq $env:DEVSTACK_SETVALUE)'),
        reason: 'an unconditional clear would delete the user own JAVA_HOME',
      );
    });
  });
}
