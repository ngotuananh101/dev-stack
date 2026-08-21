import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'background_process.dart';
import 'log_service.dart';
import '../../features/apps/domain/app_model.dart';
import '../config/app_config.dart';

part 'path_service.g.dart';

@riverpod
PathService pathService(Ref ref) {
  final logger = ref.read(logServiceProvider);
  return PathService(logger);
}

class PathService {
  final LogService _logger;
  static String get binDir => AppConfig.binDir;

  PathService(this._logger);

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

      if (Platform.isLinux) {
        await ensureLinuxProfilePath();
        return;
      }

      final result = await BackgroundProcess.run('powershell', [
        '-NoProfile',
        '-Command',
        '[Environment]::GetEnvironmentVariable("PATH", "User")',
      ]);

      if (result.exitCode != 0) {
        throw Exception('Failed to read User PATH');
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

        final setXResult = await BackgroundProcess.run('powershell', [
          '-NoProfile',
          '-Command',
          r'[Environment]::SetEnvironmentVariable($args[0], $args[1], "User")',
          'PATH',
          newPath,
        ]);

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
      if (Platform.isLinux) {
        await ensureLinuxProfilePath(binDirOverride: pathToAdd);
        return;
      }

      final result = await BackgroundProcess.run('powershell', [
        '-NoProfile',
        '-Command',
        '[Environment]::GetEnvironmentVariable("PATH", "User")',
      ]);

      if (result.exitCode != 0) return;

      final currentPath = result.stdout.toString().trim();
      final paths = currentPath.split(';');

      if (!paths.any(
        (p) => p.trim().toLowerCase() == pathToAdd.toLowerCase(),
      )) {
        _logger.info('Adding $pathToAdd to User PATH...');
        final newPath = currentPath.isEmpty
            ? pathToAdd
            : '$currentPath;$pathToAdd';

        await BackgroundProcess.run('powershell', [
          '-NoProfile',
          '-Command',
          r'[Environment]::SetEnvironmentVariable($args[0], $args[1], "User")',
          'PATH',
          newPath,
        ]);
      }
    } catch (e) {
      _logger.error('Error adding raw path to PATH: $e');
    }
  }

  /// Thiết lập biến môi trường User
  Future<void> setUserEnvVar(String name, String value) async {
    try {
      _logger.info('Setting User Environment Variable: $name = $value');
      if (Platform.isLinux) {
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

      await BackgroundProcess.run('powershell', [
        '-NoProfile',
        '-Command',
        r'[Environment]::SetEnvironmentVariable($args[0], $args[1], "User")',
        name,
        value,
      ]);
    } catch (e) {
      _logger.error('Error setting environment variable $name: $e');
    }
  }

  /// Xóa một đường dẫn trực tiếp khỏi User PATH
  Future<void> removeRawPathFromUserPath(String pathToRemove) async {
    try {
      if (Platform.isLinux) {
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

      final result = await BackgroundProcess.run('powershell', [
        '-NoProfile',
        '-Command',
        '[Environment]::GetEnvironmentVariable("PATH", "User")',
      ]);

      if (result.exitCode != 0) return;

      final currentPath = result.stdout.toString().trim();
      final paths = currentPath.split(';');

      final newPaths = paths
          .where((p) => p.trim().toLowerCase() != pathToRemove.toLowerCase())
          .toList();

      if (newPaths.length != paths.length) {
        _logger.info('Removing $pathToRemove from User PATH...');
        final newPathString = newPaths.join(';');

        await BackgroundProcess.run('powershell', [
          '-NoProfile',
          '-Command',
          r'[Environment]::SetEnvironmentVariable($args[0], $args[1], "User")',
          'PATH',
          newPathString,
        ]);
      }
    } catch (e) {
      _logger.error('Error removing raw path from PATH: $e');
    }
  }

  /// Xóa biến môi trường User
  Future<void> removeUserEnvVar(String name) async {
    try {
      _logger.info('Removing User Environment Variable: $name');
      if (Platform.isLinux) {
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

      await BackgroundProcess.run('powershell', [
        '-NoProfile',
        '-Command',
        r'[Environment]::SetEnvironmentVariable($args[0], $null, "User")',
        name,
      ]);
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

    final shimName = app.appId; // Sử dụng appId làm lệnh chính (vd: nodejs / nodejs.bat)
    final cliName = p.basenameWithoutExtension(app.cliFile ?? app.appId);

    if (Platform.isLinux) {
      await createLinuxSymlinkOrShim(binDir, shimName, app.cliFilePath!);
      if (cliName != shimName) {
        await createLinuxSymlinkOrShim(binDir, cliName, app.cliFilePath!);
      }

      // Special handling for Node.js on Linux
      if (app.appId.contains('nodejs')) {
        final nodeDir = p.dirname(app.cliFilePath!);
        final npmBin = p.join(nodeDir, 'npm');
        final npxBin = p.join(nodeDir, 'npx');
        final corepackBin = p.join(nodeDir, 'corepack');

        if (File(npmBin).existsSync() || Link(npmBin).existsSync()) {
          await createLinuxSymlinkOrShim(binDir, 'npm', npmBin);
          try {
            await Process.run(npmBin, ['config', 'set', 'prefix', binDir, '-g']);
            _logger.info('Set npm global prefix to $binDir');
          } catch (e) {
            _logger.error('Failed to set npm global prefix on Linux: $e');
          }
        }

        if (File(npxBin).existsSync() || Link(npxBin).existsSync()) {
          await createLinuxSymlinkOrShim(binDir, 'npx', npxBin);
        }

        if (File(corepackBin).existsSync() || Link(corepackBin).existsSync()) {
          await createLinuxSymlinkOrShim(binDir, 'corepack', corepackBin);
        }
      }

      _logger.info('Created Linux symlinks/shims for ${app.name} in $binDir');
      return;
    }

    // Windows implementation
    // Tạo shim cho appId
    await _createShimSet(shimName, app.cliFilePath!);

    // Tạo shim cho cli_file nếu khác appId (vd: node.bat)
    if (cliName != shimName) {
      await _createShimSet(cliName, app.cliFilePath!);
    }

    // Special handling for Node.js: Add npm and npx
    if (app.appId.contains('nodejs')) {
      final nodeDir = p.dirname(app.cliFilePath!);
      final npmCmd = p.join(nodeDir, 'npm.cmd');
      final npxCmd = p.join(nodeDir, 'npx.cmd');
      final corepackCmd = p.join(nodeDir, 'corepack.cmd');

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

      if (File(npmCmd).existsSync()) {
        await _createShimSet('npm', npmCmd);

        // Cấu hình npm global prefix trỏ về thư mục C:\Ponta\bin
        // Để các lệnh cài đặt global như `npm i -g pnpm`, `yarn` v.v. được ghi thẳng vào C:\Ponta\bin
        // Và người dùng có thể sử dụng được ngay lập tức từ terminal.
        try {
          await Process.run('cmd', [
            '/c',
            npmCmd,
            'config',
            'set',
            'prefix',
            binDir,
            '-g',
          ]);
          _logger.info('Set npm global prefix to $binDir');
        } catch (e) {
          _logger.error('Failed to set npm global prefix: $e');
        }
      }
      if (File(npxCmd).existsSync()) {
        await _createShimSet('npx', npxCmd);
      }
      if (File(corepackCmd).existsSync()) {
        await _createShimSet('corepack', corepackCmd);
      }
    }

    _logger.info('Created shims for ${app.name} in $binDir');
  }

  /// Xóa file shim / symlink của app
  Future<void> removeAppFromPath(AppModel app) async {
    final shimName = app.appId;
    final cliName = p.basenameWithoutExtension(app.cliFile ?? app.appId);

    if (Platform.isLinux) {
      final pathsToDelete = [
        ...shimPathsFor(binDir, shimName, isLinux: true),
        if (cliName != shimName) ...shimPathsFor(binDir, cliName, isLinux: true),
      ];

      for (final path in pathsToDelete) {
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

      if (app.appId.contains('nodejs')) {
        for (final extraCmd in ['npm', 'npx', 'corepack']) {
          final pth = p.join(binDir, extraCmd);
          final link = Link(pth);
          final file = File(pth);
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
        await _cleanNpmGlobals();
      }

      _logger.info('Removed Linux shims for ${app.name} from $binDir');
      return;
    }

    await _deleteShimSet(shimName);

    if (cliName != shimName) {
      await _deleteShimSet(cliName);
    }

    if (app.appId.contains('nodejs')) {
      final nodeExe = File(p.join(binDir, 'node.exe'));
      if (nodeExe.existsSync()) {
        try {
          nodeExe.deleteSync();
        } catch (_) {}
      }

      await _deleteShimSet('npm');
      await _deleteShimSet('npx');
      await _deleteShimSet('corepack');

      // Clean up global npm packages (node_modules and wrappers)
      await _cleanNpmGlobals();
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
