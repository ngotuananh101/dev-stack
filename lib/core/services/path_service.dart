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
  static const String binDir = AppConfig.binDir;

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

    _logger.info('Removed shims for ${app.name} from $binDir');
  }

  Future<void> _createShim(String commandName, String targetPath) async {
    final shimFile = File(p.join(binDir, '$commandName.bat'));
    final content = '@echo off\r\n"$targetPath" %*';
    await shimFile.writeAsString(content);
  }
}
