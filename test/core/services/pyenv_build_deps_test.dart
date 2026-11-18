import 'dart:io';

import 'package:dev_stack/core/services/pyenv_build_deps.dart';
import 'package:dev_stack/core/services/pyenv_build_deps_declines.dart';
import 'package:dev_stack/core/services/ssl_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildDepsFor', () {
    test('fedora resolves the wiki dnf list', () {
      final deps = PyenvBuildDeps.buildDepsFor(
        osReleaseId: 'fedora',
        osReleaseIdLike: '',
      );
      expect(deps?.packageManager, equals('dnf'));
      expect(
        deps?.deps.map((d) => d.package),
        containsAll(['openssl-devel', 'readline-devel', 'gdbm-devel']),
      );
    });

    test('ubuntu resolves the wiki apt-get list', () {
      final deps = PyenvBuildDeps.buildDepsFor(
        osReleaseId: 'ubuntu',
        osReleaseIdLike: 'debian',
      );
      expect(deps?.packageManager, equals('apt-get'));
      expect(
        deps?.deps.map((d) => d.package),
        containsAll(['libssl-dev', 'libreadline-dev', 'tk-dev']),
      );
    });

    test('an unknown distro resolves to null', () {
      expect(
        PyenvBuildDeps.buildDepsFor(
          osReleaseId: 'gentoo',
          osReleaseIdLike: '',
        ),
        isNull,
      );
    });
  });

  group('wikiInstallCommandFor', () {
    test('the fedora hint names the full wiki command, including libnsl2-devel', () {
      final command = PyenvBuildDeps.wikiInstallCommandFor(
        osReleaseId: 'fedora',
        osReleaseIdLike: '',
      );
      expect(command, contains('dnf install'));
      expect(command, contains('libnsl2-devel'));
    });

    test('an unknown distro has no hint command', () {
      expect(
        PyenvBuildDeps.wikiInstallCommandFor(
          osReleaseId: 'gentoo',
          osReleaseIdLike: '',
        ),
        isNull,
      );
    });
  });

  group('missingPackages', () {
    test('missingPackages returns only the packages whose probe is absent', () async {
      final deps = [
        (package: 'openssl-devel', probe: '/usr/include/openssl/ssl.h'),
        (package: 'readline-devel', probe: '/usr/include/readline/readline.h'),
      ];
      final missing = await PyenvBuildDeps.missingPackages(
        deps,
        probeExists: (probe) async => probe.contains('openssl'),
      );
      expect(missing, equals(['readline-devel']));
    });
  });

  group('ensureBuildDeps', () {
    late Directory tempDir;
    late PyenvBuildDepsDeclines declines;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ponta_pyenv_deps_');
      declines = PyenvBuildDepsDeclines('${tempDir.path}/declines.json');
    });

    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    /// Runs the flow and records every prompt, elevated command, progress
    /// event, and decline it produced.
    Future<
      ({
        List<List<String>> commands,
        List<String> prompts,
        List<bool> answers,
        Set<String> declined,
        List<SslInstallProgress> progress,
        bool proceed,
      })
    >
    run({
      required List<bool> answers,
      List<String> missingPackages = const [
        'openssl-devel',
        'readline-devel',
      ],
      ({String packageManager, List<String> packageNames})? package = const (
        packageManager: 'dnf',
        packageNames: ['openssl-devel', 'readline-devel'],
      ),
      Set<String> alreadyDeclined = const {},
      int exitCode = 0,
      int refreshExitCode = 0,
      String stderr = '',
      List<String> missingAfterwards = const [],
      Future<bool> Function()? pkexecAvailable,
    }) async {
      for (final key in alreadyDeclined) {
        await declines.decline(key);
      }
      final commands = <List<String>>[];
      final prompts = <String>[];
      final given = <bool>[];
      final progress = <SslInstallProgress>[];
      var answerIndex = 0;
      var callIndex = 0;

      final proceed = await PyenvBuildDeps.ensureBuildDeps(
        askPermission: (prompt) async {
          prompts.add(prompt.command);
          final answer = answers[answerIndex++];
          given.add(answer);
          return answer;
        },
        declines: declines,
        missingPackages: missingPackages,
        package: package,
        runElevated: (executable, arguments) async {
          commands.add([executable, ...arguments]);
          final code = callIndex++ == 0 ? refreshExitCode : exitCode;
          return ProcessResult(0, code, '', stderr);
        },
        onProgress: progress.add,
        missingAfterwards: () async => missingAfterwards,
        pkexecAvailable: pkexecAvailable ?? () async => true,
      );

      return (
        commands: commands,
        prompts: prompts,
        answers: given,
        declined: await declines.read(),
        progress: progress,
        proceed: proceed,
      );
    }

    test('does nothing when nothing is missing', () async {
      final result = await run(answers: [true], missingPackages: []);
      expect(result.prompts, isEmpty);
      expect(result.commands, isEmpty);
      expect(result.proceed, isTrue);
    });

    test('asks before installing, and runs the install it showed', () async {
      final result = await run(answers: [true]);
      expect(result.prompts, hasLength(1));
      expect(result.prompts.single, contains('dnf install'));
      expect(result.prompts.single, contains('openssl-devel'));
      expect(result.commands.first.first, equals('dnf'));
      expect(result.proceed, isTrue);
    });

    test('declining records the key and proceeds', () async {
      final result = await run(answers: [false]);
      expect(result.declined, contains('openssl-devel,readline-devel'));
      expect(result.commands, isEmpty);
      expect(result.proceed, isTrue);
    });

    test('a declined set asks nothing', () async {
      final result = await run(
        answers: [true],
        alreadyDeclined: {'openssl-devel,readline-devel'},
      );
      expect(result.prompts, isEmpty);
      expect(result.proceed, isTrue);
    });

    test('asks again when a different set of libraries is missing', () async {
      final result = await run(
        answers: [true],
        alreadyDeclined: {'openssl-devel'},
        missingPackages: ['openssl-devel', 'readline-devel'],
      );
      expect(result.prompts, hasLength(1));
    });

    test('unknown distro runs nothing and proceeds', () async {
      final result = await run(answers: [true], package: null);
      expect(result.prompts, isEmpty);
      expect(result.commands, isEmpty);
      expect(result.proceed, isTrue);
    });

    test('no pkexec runs nothing and proceeds', () async {
      final result = await run(
        answers: [true],
        pkexecAvailable: () async => false,
      );
      expect(result.prompts, isEmpty);
      expect(result.commands, isEmpty);
      expect(result.proceed, isTrue);
    });

    test('a failed install returns false with the failure message', () async {
      final result = await run(answers: [true], exitCode: 1, stderr: 'lock');
      expect(result.proceed, isFalse);
      expect(result.progress.last.status, equals(InstallStatus.failed));
      expect(result.progress.last.message, contains('lock'));
    });

    test('cancelling the authentication dialog records no decline', () async {
      final result = await run(answers: [true], exitCode: 126);
      expect(result.proceed, isFalse);
      expect(result.progress.last.message, contains('cancelled'));
      expect(result.declined, isEmpty);
    });

    test('reports failure when headers are still missing after a successful install', () async {
      final result = await run(
        answers: [true],
        missingAfterwards: ['openssl-devel'],
      );
      expect(result.proceed, isFalse);
      expect(result.progress.last.status, equals(InstallStatus.failed));
    });

    test('a failed index refresh still attempts the install', () async {
      final result = await run(answers: [true], refreshExitCode: 1);
      expect(result.commands, hasLength(2));
      expect(result.commands.last.first, equals('dnf'));
      expect(result.proceed, isTrue);
    });
  });
}
