import 'dart:io';

import 'package:dev_stack/core/services/ssl_install_declines.dart';
import 'package:dev_stack/core/services/ssl_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;
  late SslInstallDeclines declines;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ponta_certutil_');
    declines = SslInstallDeclines('${tempDir.path}/declines.json');
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  /// Runs the flow and records every command it tried to run elevated.
  Future<
    ({
      List<List<String>> commands,
      List<String> prompts,
      List<bool> answers,
      Set<String> declined,
      List<SslInstallProgress> progress,
    })
  >
  run({
    required List<bool> answers,
    bool certutilAvailable = false,
    ({String packageManager, String packageName})? package = const (
      packageManager: 'dnf',
      packageName: 'nss-tools',
    ),
    Set<String> alreadyDeclined = const {},
    int exitCode = 0,
    String stderr = '',
    bool certutilThereAfterwards = true,
  }) async {
    for (final key in alreadyDeclined) {
      await declines.decline(key);
    }
    final commands = <List<String>>[];
    final prompts = <String>[];
    final given = <bool>[];
    final progress = <SslInstallProgress>[];
    var answerIndex = 0;

    await SslService.ensureCertutil(
      askPermission: (prompt) async {
        prompts.add(prompt.command);
        final answer = answers[answerIndex++];
        given.add(answer);
        return answer;
      },
      declines: declines,
      certutilAvailable: certutilAvailable,
      package: package,
      runElevated: (executable, arguments) async {
        commands.add([executable, ...arguments]);
        return ProcessResult(0, exitCode, '', stderr);
      },
      onProgress: progress.add,
      certutilAfterwards: () async => certutilThereAfterwards,
    );

    return (
      commands: commands,
      prompts: prompts,
      answers: given,
      declined: await declines.read(),
      progress: progress,
    );
  }

  test('does nothing when certutil is already there', () async {
    final result = await run(answers: [true], certutilAvailable: true);

    expect(result.prompts, isEmpty, reason: 'nothing to ask, nothing missing');
    expect(result.commands, isEmpty);
  });

  test('asks before installing, and runs the install it showed', () async {
    final result = await run(answers: [true]);

    expect(result.prompts, hasLength(1));
    final shown = result.prompts.single;
    expect(shown, contains('dnf install'));
    expect(shown, contains('nss-tools'));
    expect(shown, contains('-y'), reason: 'a prompt would hang the install');

    // Both the refresher and the install actually ran.
    expect(result.commands.length, 2);
    expect(result.commands.first.first, 'dnf');
    expect(result.commands.last, ['dnf', 'install', '-y', 'nss-tools']);
  });

  test('a declined prompt installs nothing and is remembered', () async {
    final result = await run(answers: [false]);

    expect(result.prompts, hasLength(1));
    expect(result.commands, isEmpty);
    expect(result.declined, contains(SslInstallDeclines.nssTools));
  });

  test('a remembered decline is not asked about again', () async {
    final result = await run(
      answers: [true],
      alreadyDeclined: {SslInstallDeclines.nssTools},
    );

    expect(result.prompts, isEmpty);
    expect(result.commands, isEmpty);
  });

  test('an unsupported distro asks nothing and runs nothing', () async {
    final result = await run(answers: [true], package: null);

    expect(result.prompts, isEmpty);
    expect(result.commands, isEmpty);
  });

  test('a failing install is reported, not thrown', () async {
    final result = await run(answers: [true], exitCode: 1, stderr: 'no space');

    expect(result.commands, isNotEmpty);
  });

  test('reports that it started before waiting on the command', () async {
    // The install runs under pkexec, which can take a while; without this the
    // UI would sit silent from ALLOW until the process exits.
    final result = await run(answers: [true]);

    expect(result.progress, isNotEmpty);
    expect(result.progress.first.status, InstallStatus.starting);
    expect(result.progress.first.message, contains('nss-tools'));
  });

  test('reports success only when the command succeeded', () async {
    final result = await run(answers: [true]);

    final last = result.progress.last;
    expect(last.status, InstallStatus.succeeded);
    expect(last.message, contains('nss-tools'));
    expect(
      result.progress.any((p) => p.status == InstallStatus.failed),
      isFalse,
    );
  });

  test('reports the failure with the command output', () async {
    final result = await run(answers: [true], exitCode: 1, stderr: 'no space');

    final last = result.progress.last;
    expect(last.status, InstallStatus.failed);
    expect(last.message, contains('no space'));
  });

  test('a cancelled authentication is not reported as installed', () async {
    // pkexec exits 126 when its authentication dialog is dismissed. Saying
    // "installed" there would be a lie the user can see through.
    final result = await run(answers: [true], exitCode: 126);

    expect(result.progress.last.status, InstallStatus.failed);
  });

  test(
    'a zero exit is not reported as success when certutil is absent',
    () async {
      // A package manager can report success and leave the binary off the PATH
      // the app already inherited; the user would then be told it is fixed and
      // see the same certificate warning in the browser a moment later.
      final result = await run(answers: [true], certutilThereAfterwards: false);

      expect(result.progress.last.status, InstallStatus.failed);
    },
  );

  test('a decline reports nothing to install', () async {
    final result = await run(answers: [false]);

    // The user said no: there is no command to report on.
    expect(result.progress, isEmpty);
  });

  test('the install command adapts to the package manager', () async {
    final result = await run(
      answers: [true],
      package: (packageManager: 'apt-get', packageName: 'libnss3-tools'),
    );

    expect(result.prompts.single, contains('libnss3-tools'));
    expect(result.commands.last, ['apt-get', 'install', '-y', 'libnss3-tools']);
  });

  group('install failure message', () {
    test('names the exit code for an ordinary failure', () {
      expect(
        SslService.describeInstallFailure('nss-tools', 1),
        contains('nss-tools'),
      );
      expect(SslService.describeInstallFailure('nss-tools', 1), contains('1'));
    });

    test('a dismissed authentication is named, not numbered', () {
      // pkexec exits 126 when its authentication dialog is dismissed. "exit
      // code 126" tells the user nothing they can act on: they cancelled.
      final message = SslService.describeInstallFailure('nss-tools', 126);

      expect(message.toLowerCase(), contains('cancel'));
      expect(
        message,
        isNot(contains('126')),
        reason: 'the exit code is noise here',
      );
    });

    test('stderr wins over the exit code when there is any', () {
      // The package manager says why (held lock, mirror down); the number says
      // nothing the user can act on.
      expect(
        SslService.describeInstallFailure('nss-tools', 1, detail: 'no space'),
        contains('no space'),
      );
    });
  });
}
