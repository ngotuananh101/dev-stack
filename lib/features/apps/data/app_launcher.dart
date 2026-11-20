import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

final appLauncherProvider = Provider<AppLauncher>((ref) => AppLauncher());

typedef DetachedAppStarter =
    Future<void> Function(
      String executable,
      List<String> arguments,
      String workingDirectory,
    );
typedef WindowsAppRunner =
    Future<void> Function(String executable, List<String> arguments);

/// Opens GUI applications without tying their lifetime to DevStack on Linux.
class AppLauncher {
  final bool _isLinux;
  final DetachedAppStarter _startDetached;
  final WindowsAppRunner _runWindows;

  AppLauncher({
    bool? isLinux,
    DetachedAppStarter? startDetached,
    WindowsAppRunner? runWindows,
  }) : _isLinux = isLinux ?? Platform.isLinux,
       _startDetached = startDetached ?? _start,
       _runWindows = runWindows ?? _run;

  static Future<void> _start(
    String executable,
    List<String> arguments,
    String workingDirectory,
  ) async {
    await Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      mode: ProcessStartMode.detached,
      runInShell: false,
    );
  }

  static Future<void> _run(String executable, List<String> arguments) async {
    final result = await Process.run(executable, arguments);
    if (result.exitCode != 0) {
      throw ProcessException(
        executable,
        arguments,
        result.stderr.toString(),
        result.exitCode,
      );
    }
  }

  Future<void> open(String executablePath) async {
    final file = File(executablePath);
    if (!await file.exists()) {
      throw FileSystemException('Executable not found', executablePath);
    }
    if (_isLinux) {
      await _startDetached(
        file.absolute.path,
        const [],
        p.dirname(file.absolute.path),
      );
    } else {
      await _runWindows('cmd', ['/c', 'start', '', executablePath]);
    }
  }
}
