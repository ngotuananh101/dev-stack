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
  /// Includes `.bat`, `.cmd`, and an extensionless POSIX shell wrapper.
  static List<String> shimPathsFor(String binDir, String commandName) {
    return [
      p.join(binDir, '$commandName.bat'),
      p.join(binDir, '$commandName.cmd'),
      p.join(binDir, commandName),
    ];
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

  /// Đảm bảo thư mục C:\Ponta\bin tồn tại và nằm trong User PATH
  Future<void> ensurePontaBinInPath() async {
    try {
      if (!Directory(binDir).existsSync()) {
        Directory(binDir).createSync(recursive: true);
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

  /// Tạo file shim (.bat) cho app
  Future<void> addAppToPath(AppModel app) async {
    if (app.cliFilePath == null) {
      _logger.error('Cannot add ${app.name} to PATH: cliFilePath is null');
      return;
    }

    await ensurePontaBinInPath();

    final shimName = app.appId; // Sử dụng appId làm lệnh chính (vd: nodejs.bat)
    final cliName = p.basenameWithoutExtension(app.cliFile ?? app.appId);

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

  /// Xóa file shim của app
  Future<void> removeAppFromPath(AppModel app) async {
    final shimName = app.appId;
    final cliName = p.basenameWithoutExtension(app.cliFile ?? app.appId);

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
