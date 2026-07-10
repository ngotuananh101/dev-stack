import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Runs non-interactive child processes without creating console windows.
abstract final class BackgroundProcess {
  static const startMode = ProcessStartMode.detached;

  /// Starts a long-running managed process without displaying a console.
  ///
  /// On Windows, Dart tracks the GUI-subsystem wscript host, which waits for
  /// the real child and returns its exit code. The real PID is written by the
  /// wrapper and used by [stopManaged].
  static Future<ManagedBackgroundProcess> start(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
  }) async {
    if (!Platform.isWindows) {
      final process = await Process.start(
        executable,
        arguments,
        workingDirectory: workingDirectory,
        environment: environment,
        includeParentEnvironment: includeParentEnvironment,
      );
      return ManagedBackgroundProcess._(process, Future.value(process.pid));
    }

    final files = await _HiddenProcessFiles.create();
    final script = _buildManagedStartScript(
      executable,
      arguments,
      files,
      workingDirectory: workingDirectory,
      environment: environment,
    );
    await files.powerShell.writeAsString(script);
    await files.vbScript.writeAsString(
      _buildHiddenLauncher(files.powerShell.path),
    );

    final host = await Process.start('wscript.exe', [
      '//B',
      '//NoLogo',
      files.vbScript.path,
    ]);
    final childPid = _waitForPid(files.pid);
    final managed = ManagedBackgroundProcess._(host, childPid);
    unawaited(managed.exitCode.whenComplete(files.dispose));
    return managed;
  }

  static Future<void> stopManaged(ManagedBackgroundProcess process) async {
    if (!Platform.isWindows) {
      process.kill();
      return;
    }

    final childPid = await process.childPid.timeout(
      const Duration(seconds: 3),
      onTimeout: () => process.pid,
    );
    await run('taskkill', ['/F', '/T', '/PID', '$childPid']);
  }

  /// Runs a short command to completion without displaying a console window.
  static Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    Encoding? stdoutEncoding = systemEncoding,
    Encoding? stderrEncoding = systemEncoding,
  }) async {
    if (!Platform.isWindows) {
      return Process.run(
        executable,
        arguments,
        workingDirectory: workingDirectory,
        environment: environment,
        includeParentEnvironment: includeParentEnvironment,
        runInShell: runInShell,
        stdoutEncoding: stdoutEncoding,
        stderrEncoding: stderrEncoding,
      );
    }

    final files = await _HiddenProcessFiles.create();
    try {
      final script = _buildRunScript(
        executable,
        arguments,
        files,
        workingDirectory: workingDirectory,
        environment: environment,
      );
      await files.powerShell.writeAsString(script);
      await files.vbScript.writeAsString(
        _buildHiddenLauncher(files.powerShell.path),
      );

      final launcherResult = await Process.run('wscript.exe', [
        '//B',
        '//NoLogo',
        files.vbScript.path,
      ]);
      final exitCode = await files.readExitCode(launcherResult.exitCode);
      final stdoutBytes = await files.readBytes(files.stdout);
      final stderrBytes = await files.readBytes(files.stderr);

      return ProcessResult(
        launcherResult.pid,
        exitCode,
        _decode(stdoutBytes, stdoutEncoding),
        _decode(stderrBytes, stderrEncoding),
      );
    } finally {
      await files.dispose();
    }
  }

  /// Runs a command with Windows elevation. The UAC consent dialog remains
  /// visible, while PowerShell and the elevated console stay hidden.
  static Future<ProcessResult> runElevated(
    String executable,
    List<String> arguments,
  ) async {
    if (!Platform.isWindows) return run(executable, arguments);

    final files = await _HiddenProcessFiles.create();
    try {
      final argumentString = _windowsCommandLine(arguments);
      final script =
          '''
\$ErrorActionPreference = 'Stop'
try {
  \$process = Start-Process -FilePath ${_powerShellLiteral(executable)} -ArgumentList ${_powerShellLiteral(argumentString)} -Verb RunAs -WindowStyle Hidden -Wait -PassThru
  [IO.File]::WriteAllText(${_powerShellLiteral(files.exitCode.path)}, [string]\$process.ExitCode)
} catch {
  [IO.File]::WriteAllText(${_powerShellLiteral(files.stderr.path)}, \$_.Exception.Message)
  [IO.File]::WriteAllText(${_powerShellLiteral(files.exitCode.path)}, '1')
}
''';
      await files.powerShell.writeAsString(script);
      await files.vbScript.writeAsString(
        _buildHiddenLauncher(files.powerShell.path),
      );

      final launcherResult = await Process.run('wscript.exe', [
        '//B',
        '//NoLogo',
        files.vbScript.path,
      ]);
      final exitCode = await files.readExitCode(launcherResult.exitCode);

      return ProcessResult(
        launcherResult.pid,
        exitCode,
        '',
        utf8.decode(await files.readBytes(files.stderr), allowMalformed: true),
      );
    } finally {
      await files.dispose();
    }
  }

  static Future<ProcessResult> runElevatedPowerShell(String script) {
    return runElevated('powershell', [
      '-NoLogo',
      '-NoProfile',
      '-NonInteractive',
      '-WindowStyle',
      'Hidden',
      '-EncodedCommand',
      _powerShellEncodedCommand(script),
    ]);
  }

  static String _buildManagedStartScript(
    String executable,
    List<String> arguments,
    _HiddenProcessFiles files, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) {
    final environmentSetup = _environmentSetup(environment);
    final workingDirectorySetup = workingDirectory == null
        ? ''
        : '\$info.WorkingDirectory = ${_powerShellLiteral(workingDirectory)}';

    return '''
\$ErrorActionPreference = 'Stop'
try {
  \$info = New-Object Diagnostics.ProcessStartInfo
  \$info.FileName = ${_powerShellLiteral(executable)}
  \$info.Arguments = ${_powerShellLiteral(_windowsCommandLine(arguments))}
  \$info.UseShellExecute = \$false
  \$info.CreateNoWindow = \$true
  $workingDirectorySetup
  $environmentSetup
  \$process = New-Object Diagnostics.Process
  \$process.StartInfo = \$info
  [void]\$process.Start()
  [IO.File]::WriteAllText(${_powerShellLiteral(files.pid.path)}, [string]\$process.Id)
  \$process.WaitForExit()
  exit \$process.ExitCode
} catch {
  [IO.File]::WriteAllText(${_powerShellLiteral(files.stderr.path)}, \$_.Exception.Message)
  exit 1
}
''';
  }

  static String _buildRunScript(
    String executable,
    List<String> arguments,
    _HiddenProcessFiles files, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) {
    final environmentSetup = _environmentSetup(environment);
    final workingDirectorySetup = workingDirectory == null
        ? ''
        : '\$info.WorkingDirectory = ${_powerShellLiteral(workingDirectory)}';

    return '''
\$ErrorActionPreference = 'Stop'
\$utf8 = New-Object Text.UTF8Encoding(\$false)
try {
  \$info = New-Object Diagnostics.ProcessStartInfo
  \$info.FileName = ${_powerShellLiteral(executable)}
  \$info.Arguments = ${_powerShellLiteral(_windowsCommandLine(arguments))}
  \$info.UseShellExecute = \$false
  \$info.CreateNoWindow = \$true
  \$info.RedirectStandardOutput = \$true
  \$info.RedirectStandardError = \$true
  $workingDirectorySetup
  $environmentSetup
  \$process = New-Object Diagnostics.Process
  \$process.StartInfo = \$info
  [void]\$process.Start()
  \$stdout = \$process.StandardOutput.ReadToEnd()
  \$stderr = \$process.StandardError.ReadToEnd()
  \$process.WaitForExit()
  [IO.File]::WriteAllText(${_powerShellLiteral(files.stdout.path)}, \$stdout, \$utf8)
  [IO.File]::WriteAllText(${_powerShellLiteral(files.stderr.path)}, \$stderr, \$utf8)
  [IO.File]::WriteAllText(${_powerShellLiteral(files.exitCode.path)}, [string]\$process.ExitCode)
} catch {
  [IO.File]::WriteAllText(${_powerShellLiteral(files.stderr.path)}, \$_.Exception.Message, \$utf8)
  [IO.File]::WriteAllText(${_powerShellLiteral(files.exitCode.path)}, '1')
}
''';
  }

  static String _environmentSetup(Map<String, String>? environment) {
    return environment?.entries
            .map(
              (entry) =>
                  "\$info.EnvironmentVariables[${_powerShellLiteral(entry.key)}] = ${_powerShellLiteral(entry.value)}",
            )
            .join('\n') ??
        '';
  }

  static Future<int> _waitForPid(File pidFile) async {
    for (var attempt = 0; attempt < 100; attempt++) {
      if (pidFile.existsSync()) {
        final value = int.tryParse((await pidFile.readAsString()).trim());
        if (value != null) return value;
      }
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    throw StateError('Background process did not publish its PID');
  }

  static String _buildHiddenLauncher(String scriptPath) {
    final command =
        'powershell.exe -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "$scriptPath"';
    return 'Set shell = CreateObject("WScript.Shell")\r\n'
        'code = shell.Run("${command.replaceAll('"', '""')}", 0, True)\r\n'
        'WScript.Quit code\r\n';
  }

  static String _windowsCommandLine(List<String> arguments) {
    return arguments.map(_quoteWindowsArgument).join(' ');
  }

  static String _quoteWindowsArgument(String argument) {
    if (argument.isEmpty) return '""';
    if (!RegExp(r'[\s"]').hasMatch(argument)) return argument;

    final result = StringBuffer('"');
    var backslashes = 0;
    for (final codeUnit in argument.codeUnits) {
      if (codeUnit == 0x5c) {
        backslashes++;
      } else if (codeUnit == 0x22) {
        result.write('\\' * (backslashes * 2 + 1));
        result.write('"');
        backslashes = 0;
      } else {
        result.write('\\' * backslashes);
        result.writeCharCode(codeUnit);
        backslashes = 0;
      }
    }
    result.write('\\' * (backslashes * 2));
    result.write('"');
    return result.toString();
  }

  static dynamic _decode(List<int> bytes, Encoding? encoding) {
    return encoding == null ? bytes : encoding.decode(bytes);
  }

  static String _powerShellLiteral(String value) {
    return "'${value.replaceAll("'", "''")}'";
  }

  static String _powerShellEncodedCommand(String script) {
    final bytes = <int>[];
    for (final codeUnit in script.codeUnits) {
      bytes
        ..add(codeUnit & 0xff)
        ..add(codeUnit >> 8);
    }
    return base64Encode(bytes);
  }
}

final class ManagedBackgroundProcess {
  final Process _host;
  final Future<int> childPid;

  ManagedBackgroundProcess._(this._host, this.childPid);

  factory ManagedBackgroundProcess.wrap(Process process) {
    return ManagedBackgroundProcess._(process, Future.value(process.pid));
  }

  int get pid => _host.pid;
  Future<int> get exitCode => _host.exitCode;
  Stream<List<int>> get stdout => _host.stdout;
  Stream<List<int>> get stderr => _host.stderr;

  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    return _host.kill(signal);
  }
}

final class _HiddenProcessFiles {
  final Directory directory;
  final File powerShell;
  final File vbScript;
  final File stdout;
  final File stderr;
  final File exitCode;
  final File pid;

  _HiddenProcessFiles._(this.directory)
    : powerShell = File('${directory.path}\\run.ps1'),
      vbScript = File('${directory.path}\\run.vbs'),
      stdout = File('${directory.path}\\stdout.txt'),
      stderr = File('${directory.path}\\stderr.txt'),
      exitCode = File('${directory.path}\\exit.txt'),
      pid = File('${directory.path}\\pid.txt');

  static Future<_HiddenProcessFiles> create() async {
    final directory = await Directory.systemTemp.createTemp('ponta_process_');
    return _HiddenProcessFiles._(directory);
  }

  Future<List<int>> readBytes(File file) async {
    return file.existsSync() ? file.readAsBytes() : const [];
  }

  Future<int> readExitCode(int fallback) async {
    if (!exitCode.existsSync()) return fallback == 0 ? 1 : fallback;
    return int.tryParse((await exitCode.readAsString()).trim()) ?? 1;
  }

  Future<void> dispose() async {
    if (directory.existsSync()) {
      await directory.delete(recursive: true);
    }
  }
}
