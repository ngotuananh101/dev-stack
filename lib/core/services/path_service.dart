import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
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

  /// Đảm bảo thư mục C:\Ponta\bin tồn tại và nằm trong User PATH
  Future<void> ensurePontaBinInPath() async {
    try {
      if (!Directory(binDir).existsSync()) {
        Directory(binDir).createSync(recursive: true);
      }

      final result = await Process.run('powershell', [
        '-Command',
        '[Environment]::GetEnvironmentVariable("PATH", "User")'
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
        
        final setXResult = await Process.run('powershell', [
          '-Command',
          '[Environment]::SetEnvironmentVariable("PATH", "$newPath", "User")'
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
      final result = await Process.run('powershell', [
        '-Command',
        '[Environment]::GetEnvironmentVariable("PATH", "User")'
      ]);

      if (result.exitCode != 0) return;

      final currentPath = result.stdout.toString().trim();
      final paths = currentPath.split(';');
      
      if (!paths.any((p) => p.trim().toLowerCase() == pathToAdd.toLowerCase())) {
        _logger.info('Adding $pathToAdd to User PATH...');
        final newPath = currentPath.isEmpty ? pathToAdd : '$currentPath;$pathToAdd';
        
        await Process.run('powershell', [
          '-Command',
          "[Environment]::SetEnvironmentVariable(\"PATH\", \"$newPath\", \"User\")"
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
      await Process.run('powershell', [
        '-Command',
        "[Environment]::SetEnvironmentVariable(\"$name\", \"$value\", \"User\")"
      ]);
    } catch (e) {
      _logger.error('Error setting environment variable $name: $e');
    }
  }

  /// Xóa một đường dẫn trực tiếp khỏi User PATH
  Future<void> removeRawPathFromUserPath(String pathToRemove) async {
    try {
      final result = await Process.run('powershell', [
        '-Command',
        '[Environment]::GetEnvironmentVariable("PATH", "User")'
      ]);

      if (result.exitCode != 0) return;

      final currentPath = result.stdout.toString().trim();
      final paths = currentPath.split(';');
      
      final newPaths = paths.where((p) => p.trim().toLowerCase() != pathToRemove.toLowerCase()).toList();
      
      if (newPaths.length != paths.length) {
        _logger.info('Removing $pathToRemove from User PATH...');
        final newPathString = newPaths.join(';');
        
        await Process.run('powershell', [
          '-Command',
          "[Environment]::SetEnvironmentVariable(\"PATH\", \"$newPathString\", \"User\")"
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
      await Process.run('powershell', [
        '-Command',
        '[Environment]::SetEnvironmentVariable("$name", \$null, "User")'
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
    await _createShim(shimName, app.cliFilePath!);
    
    // Tạo shim cho cli_file nếu khác appId (vd: node.bat)
    if (cliName != shimName) {
      await _createShim(cliName, app.cliFilePath!);
    }
    
    // Special handling for Node.js: Add npm and npx
    if (app.appId.contains('nodejs')) {
      final nodeDir = p.dirname(app.cliFilePath!);
      final npmCmd = p.join(nodeDir, 'npm.cmd');
      final npxCmd = p.join(nodeDir, 'npx.cmd');
      final corepackCmd = p.join(nodeDir, 'corepack.cmd');

      if (File(npmCmd).existsSync()) {
        await _createShim('npm', npmCmd);
        
        // Cấu hình npm global prefix trỏ về thư mục C:\Ponta\bin
        // Để các lệnh cài đặt global như `npm i -g pnpm`, `yarn` v.v. được ghi thẳng vào C:\Ponta\bin
        // Và người dùng có thể sử dụng được ngay lập tức từ terminal.
        try {
          await Process.run('cmd', ['/c', npmCmd, 'config', 'set', 'prefix', binDir, '-g']);
          _logger.info('Set npm global prefix to $binDir');
        } catch (e) {
          _logger.error('Failed to set npm global prefix: $e');
        }
      }
      if (File(npxCmd).existsSync()) {
        await _createShim('npx', npxCmd);
      }
      if (File(corepackCmd).existsSync()) {
        await _createShim('corepack', corepackCmd);
      }
    }

    _logger.info('Created shims for ${app.name} in $binDir');
  }

  /// Xóa file shim (.bat) của app
  Future<void> removeAppFromPath(AppModel app) async {
    final shimName = app.appId;
    final cliName = p.basenameWithoutExtension(app.cliFile ?? app.appId);

    final shimFile1 = File(p.join(binDir, '$shimName.bat'));
    if (shimFile1.existsSync()) shimFile1.deleteSync();

    if (cliName != shimName) {
      final shimFile2 = File(p.join(binDir, '$cliName.bat'));
      if (shimFile2.existsSync()) shimFile2.deleteSync();
    }

    if (app.appId.contains('nodejs')) {
      final npmShim = File(p.join(binDir, 'npm.bat'));
      final npxShim = File(p.join(binDir, 'npx.bat'));
      final corepackShim = File(p.join(binDir, 'corepack.bat'));
      if (npmShim.existsSync()) npmShim.deleteSync();
      if (npxShim.existsSync()) npxShim.deleteSync();
      if (corepackShim.existsSync()) corepackShim.deleteSync();
    }

    _logger.info('Removed shims for ${app.name} from $binDir');
  }

  Future<void> _createShim(String commandName, String targetPath) async {
    final shimFile = File(p.join(binDir, '$commandName.bat'));
    final content = '@echo off\r\n"$targetPath" %*';
    await shimFile.writeAsString(content);
  }
}
