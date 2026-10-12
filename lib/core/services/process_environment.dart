import 'dart:io';

/// Builds the environment for a spawned CLI / supervised process.
///
/// A process launched from a desktop app inherits a minimal environment with
/// no login shell, so common toolchain directories (nvm, bun, deno, cargo,
/// `/usr/local/bin`, …) are prepended to `PATH`. Without this, commands like
/// `npm`, `node` or `deno` fail with "command not found".
///
/// [extra] entries are merged on top of the enriched parent environment and win
/// on key collisions (e.g. a program's own environment variables).
Map<String, String> buildEnrichedEnvironment({Map<String, String>? extra}) {
  final env = Map<String, String>.from(Platform.environment);
  final home =
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '';
  final pathSeparator = Platform.isWindows ? ';' : ':';
  final currentPath = env['PATH'] ?? '';

  final extraPaths = <String>[];
  if (Platform.isLinux || Platform.isMacOS) {
    extraPaths.addAll([
      '$home/.nvm/versions/node/current/bin',
      '$home/.bun/bin',
      '$home/.deno/bin',
      '$home/.cargo/bin',
      '/usr/local/bin',
      '/usr/bin',
      '/bin',
    ]);
  } else if (Platform.isWindows) {
    final appData = Platform.environment['APPDATA'] ?? '';
    final localAppData = Platform.environment['LOCALAPPDATA'] ?? '';
    extraPaths.addAll([
      '$appData\\npm',
      '$localAppData\\Programs\\bun',
      '$home\\.deno\\bin',
    ]);
  }

  final validExtras =
      extraPaths.where((path) => Directory(path).existsSync()).toList();
  if (validExtras.isNotEmpty) {
    env['PATH'] =
        '${validExtras.join(pathSeparator)}$pathSeparator$currentPath';
  }

  if (extra != null) env.addAll(extra);
  return env;
}
