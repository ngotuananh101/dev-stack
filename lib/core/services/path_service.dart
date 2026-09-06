import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'background_process.dart';
import 'log_service.dart';
import '../../features/apps/domain/app_model.dart';
import '../config/app_config.dart';

part 'path_service.g.dart';

@riverpod
PathService pathService(PathServiceRef ref) {
  final logger = ref.read(logServiceProvider);
  return PathService(logger);
}

class PathService {
  final LogService _logger;
  static String get binDir => AppConfig.binDir;

  final Future<ProcessResult> Function(
    String executable,
    List<String> arguments, {
    Map<String, String>? environment,
  })? _runProcess;
  final bool Function() _isWindows;

  PathService(
    this._logger, {
    Future<ProcessResult> Function(
      String executable,
      List<String> arguments, {
      Map<String, String>? environment,
    })? runProcess,
    bool Function()? platformIsWindows,
  })  : _runProcess = runProcess,
        _isWindows = platformIsWindows ?? (() => Platform.isWindows);

  Future<ProcessResult> _run(
    String executable,
    List<String> arguments, {
    Map<String, String>? environment,
  }) {
    final runner = _runProcess;
    if (runner != null) {
      return runner(executable, arguments, environment: environment);
    }
    return BackgroundProcess.run(
      executable,
      arguments,
      environment: environment,
    );
  }

  /// Trả về thư mục chứa các global package binaries riêng biệt cho từng runtime JS
  @visibleForTesting
  static String? globalPackageDirForApp(
    String appId, {
    bool? isWindows,
    Map<String, String>? environment,
  }) {
    final env = environment ?? Platform.environment;
    final onWindows = isWindows ?? Platform.isWindows;
    final ctx = p.Context(style: onWindows ? p.Style.windows : p.Style.posix);
    final id = appId.toLowerCase();

    if (id.contains('nodejs') || id == 'node') {
      if (onWindows) {
        final appData = env['APPDATA'];
        if (appData != null && appData.isNotEmpty) {
          return ctx.join(appData, 'npm');
        }
      } else {
        final home = env['HOME'];
        if (home != null && home.isNotEmpty) {
          return ctx.join(home, '.npm-global', 'bin');
        }
      }
    }

    if (id.contains('bun')) {
      if (onWindows) {
        final userProfile = env['USERPROFILE'] ?? env['HOME'];
        if (userProfile != null && userProfile.isNotEmpty) {
          return ctx.join(userProfile, '.bun', 'bin');
        }
      } else {
        final home = env['HOME'];
        if (home != null && home.isNotEmpty) {
          return ctx.join(home, '.bun', 'bin');
        }
      }
    }

    if (id.contains('deno')) {
      if (onWindows) {
        final userProfile = env['USERPROFILE'] ?? env['HOME'];
        if (userProfile != null && userProfile.isNotEmpty) {
          return ctx.join(userProfile, '.deno', 'bin');
        }
      } else {
        final home = env['HOME'];
        if (home != null && home.isNotEmpty) {
          return ctx.join(home, '.deno', 'bin');
        }
      }
    }

    return null;
  }

  /// Returns the list of shim/command names to create for a given app identifier.
  ///
  /// - `bun` => ['bun', 'bunx']
  /// - `deno` => ['deno']
  /// - `nodejs` / `node` => ['nodejs', 'node']
  /// - `npm`, `npx`, `corepack` are handled separately in [addAppToPath] /
  ///   [removeAppFromPath] because they must target their own CLI wrapper
  ///   binaries (npm.cmd / npx.cmd / corepack.cmd) on Windows, or the
  ///   plain `npm` / `npx` / `corepack` executables on Linux.
  /// - For any other app the list is [appId] plus the base name of [cliFile]
  ///   (without extension) when provided, so that CLI aliases like `php.exe`
  ///   (appId `php84`) or `httpd.exe` (appId `apache`) are preserved.
  @visibleForTesting
  static List<String> shimNamesForApp(String appId, [String? cliFile]) {
    final id = appId.toLowerCase();

    // Runtime shim names only — auxiliary commands (npm, npx, corepack) are
    // handled in the dedicated Node.js blocks of addAppToPath/removeAppFromPath.
    if (id.contains('bun')) {
      // bun core commands; bunx is handled separately in addAppToPath for
      // Windows because it may target bunx.exe specifically.
      return ['bun'];
    }
    if (id.contains('deno')) {
      return ['deno'];
    }
    if (id.contains('nodejs') || id == 'node') {
      return ['nodejs', 'node'];
    }

    // Generic apps (php, httpd, psql, redis-cli, etc.)
    final names = <String>[appId];
    if (cliFile != null && cliFile.isNotEmpty) {
      final baseName = p.basenameWithoutExtension(cliFile);
      if (baseName.isNotEmpty && !names.contains(baseName)) {
        names.add(baseName);
      }
    }
    return names;
  }

  /// Builds the PowerShell arguments and environment map to set a User environment variable on Windows.
  @visibleForTesting
  static ({List<String> arguments, Map<String, String> environment})
      windowsSetUserEnvCommand(String name, String value) {
    return (
      arguments: [
        '-NoProfile',
        '-Command',
        r'[Environment]::SetEnvironmentVariable($env:DEVSTACK_ENVVAR, $env:DEVSTACK_SETVALUE, "User")',
      ],
      environment: {
        'DEVSTACK_ENVVAR': name,
        'DEVSTACK_SETVALUE': value,
      },
    );
  }

  /// Builds the PowerShell arguments and environment map to remove a User environment variable on Windows.
  @visibleForTesting
  static ({List<String> arguments, Map<String, String> environment})
      windowsRemoveUserEnvCommand(String name) {
    return (
      arguments: [
        '-NoProfile',
        '-Command',
        r'[Environment]::SetEnvironmentVariable($env:DEVSTACK_ENVVAR, $null, "User")',
      ],
      environment: {
        'DEVSTACK_ENVVAR': name,
      },
    );
  }

  /// Returns the on-disk shim file paths for a command under [binDir].
  ///
  /// On Linux, returns a single extensionless path.
  /// On Windows, includes `.bat`, `.cmd`, and an extensionless POSIX shell wrapper.
  static List<String> shimPathsFor(
    String binDir,
    String commandName, {
    bool? isLinux,
  }) {
    final linux = isLinux ?? Platform.isLinux;
    if (linux) {
      return [p.join(binDir, commandName)];
    }
    return [
      p.join(binDir, '$commandName.bat'),
      p.join(binDir, '$commandName.cmd'),
      p.join(binDir, commandName),
    ];
  }

  /// Formats the `export PATH="..."` line for Linux shell profiles.
  static String linuxProfileExportLine(String binDir) {
    return 'export PATH="$binDir:\$PATH"';
  }

  /// Checks if [binDir] is already exported in the given shell profile [content].
  /// Ignores commented lines starting with '#'.
  static bool isBinInProfileContent(String content, String binDir) {
    if (content.isEmpty) return false;
    final lines = content.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('#')) continue;
      if (trimmed.contains(binDir)) return true;
    }
    return false;
  }

  /// Standard Linux shell profile files to search in [homeDir].
  static List<String> linuxShellProfilePaths(String homeDir) {
    return [
      p.join(homeDir, '.bashrc'),
      p.join(homeDir, '.zshrc'),
      p.join(homeDir, '.profile'),
    ];
  }

  /// Creates a Linux executable symlink or fallback shell wrapper in [binDir].
  static Future<void> createLinuxSymlinkOrShim(
    String binDir,
    String commandName,
    String targetPath,
  ) async {
    final linkPath = p.join(binDir, commandName);
    final linkEntity = Link(linkPath);
    final fileEntity = File(linkPath);

    // Delete existing link or file if present
    if (linkEntity.existsSync()) {
      linkEntity.deleteSync();
    } else if (fileEntity.existsSync()) {
      fileEntity.deleteSync();
    }

    try {
      linkEntity.createSync(targetPath);
    } catch (_) {
      // If symlink creation fails (e.g. unsupported filesystem), fallback to shell wrapper script
      final script = '#!/usr/bin/env sh\nexec ${shellSingleQuote(targetPath)} "\$@"\n';
      await fileEntity.writeAsString(script);
      if (Platform.isLinux) {
        await Process.run('chmod', ['755', linkPath]);
      }
    }
  }

  /// Helper to ensure Linux shell profile contains [binDir].
  Future<void> ensureLinuxProfilePath({
    String? homeDir,
    String? binDirOverride,
  }) async {
    final home = homeDir ?? Platform.environment['HOME'] ?? '';
    if (home.isEmpty) return;

    final targetBinDir = binDirOverride ?? binDir;
    final exportLine = linuxProfileExportLine(targetBinDir);
    final profilePaths = linuxShellProfilePaths(home);

    bool modifiedAny = false;
    for (final profilePath in profilePaths) {
      final file = File(profilePath);
      if (file.existsSync()) {
        final content = await file.readAsString();
        if (!isBinInProfileContent(content, targetBinDir)) {
          final prefix = (content.isNotEmpty && !content.endsWith('\n')) ? '\n' : '';
          await file.writeAsString('$prefix$exportLine\n', mode: FileMode.append);
          _logger.info('Added $targetBinDir to $profilePath');
          modifiedAny = true;
        } else {
          modifiedAny = true; // Already present
        }
      }
    }

    // If none of the profile files existed, create ~/.profile
    if (!modifiedAny) {
      final defaultProfile = File(p.join(home, '.profile'));
      await defaultProfile.writeAsString('$exportLine\n', mode: FileMode.append);
      _logger.info('Created and added $targetBinDir to ${defaultProfile.path}');
    }
  }

  /// Returns the `cmd.exe` / `.bat` / `.cmd` shim content that forwards
  /// arguments to [targetPath] and preserves the exit code.
  @visibleForTesting
  static String windowsBatchShimContent(String targetPath) {
    return '@echo off\r\n"$targetPath" %*\r\nexit /b %ERRORLEVEL%\r\n';
  }

  @visibleForTesting
  static String shellSingleQuote(String value) {
    return "'${value.replaceAll("'", "'\\''")}'";
  }

  /// Returns the POSIX shell wrapper (bash / Git Bash / MSYS2 / Cygwin / WSL)
  /// shim content that `exec`s [targetPath], converts Windows paths for WSL,
  /// and forwards arguments. Use LF line endings so the shebang is portable.
  @visibleForTesting
  static String shellShimContent(String targetPath) {
    final posixPath = targetPath.replaceAll(r'\', '/');
    final quotedPosixPath = shellSingleQuote(posixPath);
    return '#!/usr/bin/env sh\n'
        'target=$quotedPosixPath\n'
        'windows_target=$quotedPosixPath\n'
        r'case "$(uname -r 2>/dev/null | tr A-Z a-z)" in'
        '\n'
        '  *microsoft*|*wsl*)\n'
        r'    lower_target=$(printf "%s" "$windows_target" | tr A-Z a-z)'
        '\n'
        r'    case "$lower_target" in'
        '\n'
        r'      *.cmd|*.bat) exec cmd.exe /c "$windows_target" "$@" ;;'
        '\n'
        r'    esac'
        '\n'
        r'    drive=$(printf "%s" "$target" | cut -c1 | tr A-Z a-z)'
        '\n'
        r'    rest=$(printf "%s" "$target" | cut -c4-)'
        '\n'
        r'    target="/mnt/$drive/$rest"'
        '\n'
        '    ;;\n'
        'esac\n'
        r'exec "$target" "$@"'
        '\n';
  }

  /// Đảm bảo thư mục bin tồn tại và nằm trong PATH
  Future<void> ensurePontaBinInPath() async {
    try {
      if (!Directory(binDir).existsSync()) {
        Directory(binDir).createSync(recursive: true);
      }

      if (!_isWindows()) {
        await ensureLinuxProfilePath();
        return;
      }

      final result = await _run('powershell', [
        '-NoProfile',
        '-Command',
        '[Environment]::GetEnvironmentVariable("PATH", "User")',
      ]);

      if (result.exitCode != 0) {
        _logger.error('Failed to read User PATH: ${result.stderr}');
        return;
      }

      final currentPath = result.stdout.toString().trim();

      // Kiểm tra xem binDir đã có trong PATH chưa
      final paths = currentPath.split(';');
      bool alreadyInPath = false;
      for (var path in paths) {
        if (path.trim().toLowerCase() == binDir.toLowerCase()) {
          alreadyInPath = true;
          break;
        }
      }

      if (!alreadyInPath) {
        _logger.info('Adding $binDir to User PATH...');
        final newPath = currentPath.isEmpty ? binDir : '$currentPath;$binDir';

        final cmd = windowsSetUserEnvCommand('PATH', newPath);
        final setXResult = await _run(
          'powershell',
          cmd.arguments,
          environment: cmd.environment,
        );

        if (setXResult.exitCode == 0) {
          _logger.info('Successfully added $binDir to User PATH.');
        } else {
          _logger.error('Failed to update PATH: ${setXResult.stderr}');
        }
      }
    } catch (e) {
      _logger.error('Error ensuring Ponta bin in PATH: $e');
    }
  }

  /// Thêm một đường dẫn trực tiếp vào User PATH
  Future<void> addRawPathToUserPath(String pathToAdd) async {
    try {
      if (!_isWindows()) {
        await ensureLinuxProfilePath(binDirOverride: pathToAdd);
        return;
      }

      final result = await _run('powershell', [
        '-NoProfile',
        '-Command',
        '[Environment]::GetEnvironmentVariable("PATH", "User")',
      ]);

      if (result.exitCode != 0) {
        _logger.error('Failed to read User PATH: ${result.stderr}');
        return;
      }

      final currentPath = result.stdout.toString().trim();
      final paths = currentPath.split(';');

      if (!paths.any(
        (p) => p.trim().toLowerCase() == pathToAdd.toLowerCase(),
      )) {
        _logger.info('Adding $pathToAdd to User PATH...');
        final newPath = currentPath.isEmpty
            ? pathToAdd
            : '$currentPath;$pathToAdd';

        final cmd = windowsSetUserEnvCommand('PATH', newPath);
        final setResult = await _run(
          'powershell',
          cmd.arguments,
          environment: cmd.environment,
        );

        if (setResult.exitCode == 0) {
          _logger.info('Successfully added $pathToAdd to User PATH.');
        } else {
          _logger.error('Failed to update PATH with $pathToAdd: ${setResult.stderr}');
        }
      }
    } catch (e) {
      _logger.error('Error adding raw path to PATH: $e');
    }
  }

  /// Thiết lập biến môi trường User
  Future<void> setUserEnvVar(String name, String value) async {
    try {
      _logger.info('Setting User Environment Variable: $name = $value');
      if (!_isWindows()) {
        final home = Platform.environment['HOME'] ?? '';
        if (home.isNotEmpty) {
          final profilePaths = linuxShellProfilePaths(home);
          final exportLine = 'export $name="$value"';
          for (final profilePath in profilePaths) {
            final file = File(profilePath);
            if (file.existsSync()) {
              await file.writeAsString('$exportLine\n', mode: FileMode.append);
            }
          }
        }
        return;
      }

      final cmd = windowsSetUserEnvCommand(name, value);
      final result = await _run(
        'powershell',
        cmd.arguments,
        environment: cmd.environment,
      );

      if (result.exitCode == 0) {
        _logger.info('Successfully set environment variable $name.');
      } else {
        _logger.error('Failed to set environment variable $name: ${result.stderr}');
      }
    } catch (e) {
      _logger.error('Error setting environment variable $name: $e');
    }
  }

  /// Xóa một đường dẫn trực tiếp khỏi User PATH
  Future<void> removeRawPathFromUserPath(String pathToRemove) async {
    try {
      if (!_isWindows()) {
        final home = Platform.environment['HOME'] ?? '';
        if (home.isEmpty) return;
        for (final profilePath in linuxShellProfilePaths(home)) {
          final file = File(profilePath);
          if (file.existsSync()) {
            final lines = await file.readAsLines();
            final filtered = lines.where((l) => !l.contains(pathToRemove)).toList();
            await file.writeAsString('${filtered.join('\n')}\n');
          }
        }
        return;
      }

      final result = await _run('powershell', [
        '-NoProfile',
        '-Command',
        '[Environment]::GetEnvironmentVariable("PATH", "User")',
      ]);

      if (result.exitCode != 0) {
        _logger.error('Failed to read User PATH: ${result.stderr}');
        return;
      }

      final currentPath = result.stdout.toString().trim();
      final paths = currentPath.split(';');

      final newPaths = paths
          .where((p) => p.trim().toLowerCase() != pathToRemove.toLowerCase())
          .toList();

      if (newPaths.length != paths.length) {
        _logger.info('Removing $pathToRemove from User PATH...');
        final newPathString = newPaths.join(';');

        final cmd = windowsSetUserEnvCommand('PATH', newPathString);
        final removeResult = await _run(
          'powershell',
          cmd.arguments,
          environment: cmd.environment,
        );

        if (removeResult.exitCode == 0) {
          _logger.info('Successfully removed $pathToRemove from User PATH.');
        } else {
          _logger.error('Failed to update PATH: ${removeResult.stderr}');
        }
      }
    } catch (e) {
      _logger.error('Error removing raw path from PATH: $e');
    }
  }

  /// Xóa biến môi trường User
  Future<void> removeUserEnvVar(String name) async {
    try {
      _logger.info('Removing User Environment Variable: $name');
      if (!_isWindows()) {
        final home = Platform.environment['HOME'] ?? '';
        if (home.isEmpty) return;
        for (final profilePath in linuxShellProfilePaths(home)) {
          final file = File(profilePath);
          if (file.existsSync()) {
            final lines = await file.readAsLines();
            final filtered = lines.where((l) => !l.startsWith('export $name=')).toList();
            await file.writeAsString('${filtered.join('\n')}\n');
          }
        }
        return;
      }

      final cmd = windowsRemoveUserEnvCommand(name);
      final result = await _run(
        'powershell',
        cmd.arguments,
        environment: cmd.environment,
      );

      if (result.exitCode == 0) {
        _logger.info('Successfully removed environment variable $name.');
      } else {
        _logger.error('Failed to remove environment variable $name: ${result.stderr}');
      }
    } catch (e) {
      _logger.error('Error removing environment variable $name: $e');
    }
  }

  /// Tạo file shim / symlink cho app
  Future<void> addAppToPath(AppModel app) async {
    if (app.cliFilePath == null) {
      _logger.error('Cannot add ${app.name} to PATH: cliFilePath is null');
      return;
    }

    await ensurePontaBinInPath();

    final shimNames = shimNamesForApp(app.appId, app.cliFile);

    if (Platform.isLinux) {
      for (final name in shimNames) {
        await createLinuxSymlinkOrShim(binDir, name, app.cliFilePath!);
      }

      // Special handling for Node.js on Linux: configure npm prefix to ~/.npm-global
      // and create shims for npm, npx, corepack targeting their own executables.
      if (app.appId.contains('nodejs') || app.appId == 'node') {
        final nodeDir = p.dirname(app.cliFilePath!);

        // npm shim
        final npmBin = p.join(nodeDir, 'npm');
        if (File(npmBin).existsSync() || Link(npmBin).existsSync()) {
          await createLinuxSymlinkOrShim(binDir, 'npm', npmBin);
        }

        // npx shim
        final npxBin = p.join(nodeDir, 'npx');
        if (File(npxBin).existsSync() || Link(npxBin).existsSync()) {
          await createLinuxSymlinkOrShim(binDir, 'npx', npxBin);
        }

        // corepack shim
        final corepackBin = p.join(nodeDir, 'corepack');
        if (File(corepackBin).existsSync() || Link(corepackBin).existsSync()) {
          await createLinuxSymlinkOrShim(binDir, 'corepack', corepackBin);
        }

        try {
          final home = Platform.environment['HOME'] ?? '';
          final npmGlobalDir = home.isNotEmpty
              ? p.join(home, '.npm-global')
              : binDir;
          await Process.run(npmBin, ['config', 'set', 'prefix', npmGlobalDir, '-g']);
          _logger.info('Set npm global prefix to $npmGlobalDir');
        } catch (e) {
          _logger.error('Failed to set npm global prefix on Linux: $e');
        }
      }

      final globalDir = globalPackageDirForApp(app.appId);
      if (globalDir != null) {
        await addRawPathToUserPath(globalDir);
      }

      _logger.info('Created Linux symlinks/shims for ${app.name} in $binDir');
      return;
    }

    // Windows implementation
    for (final name in shimNames) {
      // On Windows, bunx should target bunx.exe if it exists, otherwise
      // fall back to the cliFilePath (which may be bun.exe).
      String targetPath = app.cliFilePath!;
      if (name == 'bunx') {
        final appDir = p.dirname(app.cliFilePath!);
        final bunxExe = p.join(appDir, 'bunx.exe');
        if (File(bunxExe).existsSync()) {
          targetPath = bunxExe;
        }
      }
      await _createShimSet(name, targetPath);
    }

    // Special handling for Node.js on Windows:
    // - Create node.exe symlink (required by npm global package installers)
    // - Create shims for npm, npx, corepack targeting their own .cmd wrappers.
    if (app.appId.contains('nodejs') || app.appId == 'node') {
      // Lệnh cài đặt global của npm (như pnpm.ps1) sẽ yêu cầu chính xác file "node.exe" tồn tại trong PATH.
      // Thay vì copy, ta tạo symlink để tiết kiệm dung lượng.
      try {
        final nodeExe = File(app.cliFilePath!);
        final symlinkPath = p.join(binDir, 'node.exe');

        if (File(symlinkPath).existsSync()) {
          File(symlinkPath).deleteSync();
        }

        if (nodeExe.existsSync()) {
          final result = await Process.run('cmd', [
            '/c',
            'mklink',
            symlinkPath,
            nodeExe.path,
          ]);
          if (result.exitCode == 0) {
            _logger.info('Created symlink for node.exe at $binDir');
          } else {
            _logger.error(
              'Failed to create symlink for node.exe: ${result.stderr}',
            );
            await nodeExe.copy(symlinkPath);
            _logger.info('Copied node.exe to $binDir as fallback');
          }
        }
      } catch (e) {
        _logger.error('Error creating symlink/copy for node.exe: $e');
      }

      final nodeDir = p.dirname(app.cliFilePath!);

      // npm shim — targets npm.cmd on Windows
      final npmCmd = p.join(nodeDir, 'npm.cmd');
      if (File(npmCmd).existsSync()) {
        await _createShimSet('npm', npmCmd);
      } else {
        // Fallback to npm (the executable wrapper without .cmd) if npm.cmd
        // is not present but npm exists.
        final npmBin = p.join(nodeDir, 'npm');
        if (File(npmBin).existsSync() || Link(npmBin).existsSync()) {
          await _createShimSet('npm', npmBin);
        }
      }

      // npx shim — targets npx.cmd on Windows
      final npxCmd = p.join(nodeDir, 'npx.cmd');
      if (File(npxCmd).existsSync()) {
        await _createShimSet('npx', npxCmd);
      } else {
        final npxBin = p.join(nodeDir, 'npx');
        if (File(npxBin).existsSync() || Link(npxBin).existsSync()) {
          await _createShimSet('npx', npxBin);
        }
      }

      // corepack shim — targets corepack.cmd on Windows
      final corepackCmd = p.join(nodeDir, 'corepack.cmd');
      if (File(corepackCmd).existsSync()) {
        await _createShimSet('corepack', corepackCmd);
      } else {
        final corepackBin = p.join(nodeDir, 'corepack');
        if (File(corepackBin).existsSync() || Link(corepackBin).existsSync()) {
          await _createShimSet('corepack', corepackBin);
        }
      }

      // Do NOT set npm prefix to binDir (C:\Ponta\bin) on Windows;
      // global packages are now isolated in the global package dir.
    }

    final globalDir = globalPackageDirForApp(app.appId);
    if (globalDir != null) {
      await addRawPathToUserPath(globalDir);
    }

    _logger.info('Created shims for ${app.name} in $binDir');
  }

  /// Xóa file shim / symlink của app
  Future<void> removeAppFromPath(AppModel app) async {
    final shimNames = shimNamesForApp(app.appId, app.cliFile);

    if (Platform.isLinux) {
      for (final name in shimNames) {
        final paths = shimPathsFor(binDir, name, isLinux: true);
        for (final path in paths) {
          final link = Link(path);
          final file = File(path);
          if (link.existsSync()) {
            try {
              link.deleteSync();
            } catch (_) {}
          } else if (file.existsSync()) {
            try {
              file.deleteSync();
            } catch (_) {}
          }
        }
      }

      if (app.appId.contains('nodejs') || app.appId == 'node') {
        final nodeExe = File(p.join(binDir, 'node.exe'));
        if (nodeExe.existsSync()) {
          try {
            nodeExe.deleteSync();
          } catch (_) {}
        }
        await _cleanNpmGlobals();
        // Remove npm, npx, corepack shims on Linux
        for (final auxName in ['npm', 'npx', 'corepack']) {
          final paths = shimPathsFor(binDir, auxName, isLinux: true);
          for (final path in paths) {
            final link = Link(path);
            final file = File(path);
            if (link.existsSync()) {
              try {
                link.deleteSync();
              } catch (_) {}
            } else if (file.existsSync()) {
              try {
                file.deleteSync();
              } catch (_) {}
            }
          }
        }
      }

      final globalDir = globalPackageDirForApp(app.appId);
      if (globalDir != null) {
        await removeRawPathFromUserPath(globalDir);
      }

      _logger.info('Removed Linux shims for ${app.name} from $binDir');
      return;
    }

    for (final name in shimNames) {
      await _deleteShimSet(name);
    }

    if (app.appId.contains('nodejs') || app.appId == 'node') {
      final nodeExe = File(p.join(binDir, 'node.exe'));
      if (nodeExe.existsSync()) {
        try {
          nodeExe.deleteSync();
        } catch (_) {}
      }
      await _cleanNpmGlobals();
      // Remove npm, npx, corepack shims on Windows
      for (final auxName in ['npm', 'npx', 'corepack']) {
        await _deleteShimSet(auxName);
      }
    }

    final globalDir = globalPackageDirForApp(app.appId);
    if (globalDir != null) {
      await removeRawPathFromUserPath(globalDir);
    }

    _logger.info('Removed shims for ${app.name} from $binDir');
  }

  Future<void> _createShimSet(String commandName, String targetPath) async {
    final legacyPowerShellShim = File(p.join(binDir, '$commandName.ps1'));
    if (legacyPowerShellShim.existsSync()) {
      await legacyPowerShellShim.delete();
    }

    final paths = shimPathsFor(binDir, commandName);
    final batchContent = windowsBatchShimContent(targetPath);
    await File(paths[0]).writeAsString(batchContent);
    await File(paths[1]).writeAsString(batchContent);
    await File(paths[2]).writeAsString(shellShimContent(targetPath));
  }

  Future<void> _deleteShimSet(String commandName) async {
    final paths = [
      ...shimPathsFor(binDir, commandName),
      // Remove legacy PowerShell shims so PowerShell does not prefer blocked .ps1 files.
      p.join(binDir, '$commandName.ps1'),
    ];
    for (final path in paths) {
      final file = File(path);
      if (file.existsSync()) {
        await file.delete();
      }
    }
  }

  Future<void> _cleanNpmGlobals() async {
    final nodeModulesDir = Directory(p.join(binDir, 'node_modules'));
    if (!nodeModulesDir.existsSync()) return;

    try {
      final binDirectory = Directory(binDir);
      final files = binDirectory.listSync().whereType<File>().toList();
      for (final file in files) {
        final ext = p.extension(file.path).toLowerCase();
        final name = p.basename(file.path).toLowerCase();

        if (name == 'composer.phar' || name == 'node.exe') continue;
        if (ext != '.bat' && ext != '.cmd' && ext != '.ps1' && ext != '') {
          continue;
        }

        try {
          final content = await file.readAsString();
          if (content.contains('node_modules')) {
            await file.delete();
          }
        } catch (e) {
          _logger.warning(
            'Skipping unreadable npm wrapper candidate ${file.path}: $e',
          );
        }
      }

      await nodeModulesDir.delete(recursive: true);
      _logger.info('Cleaned up global npm packages and wrappers from $binDir');
    } catch (e) {
      _logger.error('Failed to clean npm globals: $e');
    }
  }
}
