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
  }) async {
    for (final key in alreadyDeclined) {
      await declines.decline(key);
    }
    final commands = <List<String>>[];
    final prompts = <String>[];
    final given = <bool>[];
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
        return ProcessResult(0, exitCode, '', '');
      },
    );

    return (
      commands: commands,
      prompts: prompts,
      answers: given,
      declined: await declines.read(),
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
    final result = await run(answers: [true], exitCode: 1);

    expect(result.commands, isNotEmpty);
  });

  test('the install command adapts to the package manager', () async {
    final result = await run(
      answers: [true],
      package: (packageManager: 'apt-get', packageName: 'libnss3-tools'),
    );

    expect(result.prompts.single, contains('libnss3-tools'));
    expect(result.commands.last, ['apt-get', 'install', '-y', 'libnss3-tools']);
  });
}
