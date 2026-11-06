import 'dart:io';

import 'package:path/path.dart' as p;

import 'package_command_validator.dart';

/// Executes only narrowly validated legacy system PHP configuration changes.
/// Discovery and package/repository operations cannot enter this runner.
class PhpConfigCommandRunner {
  PhpConfigCommandRunner({
    Future<ProcessResult> Function(String, List<String>)? runProcess,
  }) : _runProcess = runProcess ?? Process.run;

  final Future<ProcessResult> Function(String, List<String>) _runProcess;

  Future<ProcessResult> run({
    required List<String> commands,
    required void Function(String) logInfo,
    required void Function(String) logError,
  }) async {
    // Validate the entire batch before even creating a script or requesting
    // authorization. A valid first command must not mask an unsafe later one.
    if (commands.isEmpty) throw StateError('No PHP configuration commands');
    final validated = List<String>.of(commands);
    for (final command in validated) {
      final rejection = PackageCommandValidator.validateConfiguration(command);
      if (rejection != null) {
        throw StateError(
          'Refusing PHP configuration command "$command": $rejection',
        );
      }
    }

    final tempDir = await Directory.systemTemp.createTemp('ponta-php-config-');
    final scriptFile = File(p.join(tempDir.path, 'configure.sh'));
    try {
      // No catalog hooks, install environment or sudo wrappers. A fixed PATH
      // prevents inherited user directories from supplying a config binary.
      await scriptFile.writeAsString(
        '#!/bin/sh\nset -e\nPATH=/usr/sbin:/usr/bin:/sbin:/bin\nexport PATH\n'
        '${validated.map((c) => c.trim()).join('\n')}\n',
      );
      logInfo('Requesting system authorization for PHP configuration...');
      final result = await _runProcess('pkexec', ['/bin/sh', scriptFile.path]);
      if (result.exitCode != 0) {
        final message = result.stderr.toString();
        logError('PHP configuration failed (${result.exitCode}): $message');
        throw ProcessException(
          'pkexec',
          ['/bin/sh', scriptFile.path],
          message,
          result.exitCode,
        );
      }
      if (result.stdout.toString().isNotEmpty) {
        logInfo(result.stdout.toString());
      }
      return result;
    } finally {
      await tempDir.delete(recursive: true);
    }
  }
}
