import 'dart:io';
import 'package:dio/dio.dart';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../domain/app_model.dart';
import '../../../core/services/log_service.dart';

part 'app_installer_service.g.dart';

@riverpod
AppInstallerService appInstallerService(Ref ref) {
  final logger = ref.read(logServiceProvider);
  return AppInstallerService(logger);
}

typedef InstallationProgressCallback = void Function(
  double progress,
  String status, {
  int? downloadedBytes,
  int? totalBytes,
});
typedef InstallationLogCallback = void Function(String message);

class AppInstallerService {
  final LogService _logger;
  static const String defaultBaseDir = 'C:\\Ponta\\apps';
  final _dio = Dio();

  AppInstallerService(this._logger);

  Future<String> install(
    AppModel app, 
    String version, {
    InstallationProgressCallback? onProgress,
    InstallationLogCallback? onLog,
  }) async {
    void logInfo(String msg) {
      _logger.info(msg);
      onLog?.call(msg);
    }

    void logError(String msg) {
      _logger.error(msg);
      onLog?.call('ERROR: $msg');
    }

    if (app.appId == 'pyenv') {
      logError('pyenv installation requested but not supported through this flow.');
      throw Exception('pyenv installation is not supported through this flow.');
    }

    final url = app.versionLinks[version];
    if (url == null || url.isEmpty) {
      _logger.error('Download URL for ${app.name} version $version not found.');
      throw Exception('Download URL for version $version not found.');
    }

    final installPath = p.join(defaultBaseDir, app.appId, version);
    final directory = Directory(installPath);
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }

    // 2. Download
    logInfo('Starting installation for ${app.name} ($version)');
    onProgress?.call(0.1, 'Downloading...');

    final tempFile = File(p.join(Directory.systemTemp.path, '${app.appId}_$version.tmp'));
    
    try {
      await _dio.download(
        url,
        tempFile.path,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = (received / total) * 0.7 + 0.1; // 10% to 80%
            onProgress?.call(
              progress,
              'Downloading...',
              downloadedBytes: received,
              totalBytes: total,
            );
          }
        },
      );

      logInfo('Download completed for ${app.name}');
      onProgress?.call(0.8, 'Extracting...');

      final bytes = await tempFile.readAsBytes();
      final extension = p.extension(url).toLowerCase();

      // 3. Extract or Save
      if (extension == '.zip') {
        logInfo('Extracting ZIP for ${app.name}');
        await _extractZip(bytes, installPath, onLog);
      } else if (extension == '.gz' || url.contains('.tar.gz')) {
        logInfo('Extracting TAR.GZ for ${app.name}');
        await _extractTarGz(bytes, installPath, onLog);
      } else {
        final filename = p.basename(url).split('?').first;
        final file = File(p.join(installPath, filename));
        await file.writeAsBytes(bytes);
      }

      // 4. Flatten directory if needed
      await _flattenDirectory(installPath, logInfo);

      // 5. Detect executable and CLI files
      logInfo('Detecting executable and CLI files...');
      final detected = await _detectFiles(
        installPath, 
        app.execFile, 
        app.cliFile, 
        logInfo
      );
      app.execFilePath = detected['exec'];
      app.cliFilePath = detected['cli'];

      onProgress?.call(1.0, 'Completed');
      logInfo('Successfully installed ${app.name} to $installPath');
      
      // Cleanup
      if (tempFile.existsSync()) await tempFile.delete();
      
      return installPath;
    } catch (e) {
      logError('Installation failed for ${app.name}: $e');
      if (tempFile.existsSync()) await tempFile.delete();
      rethrow;
    }
  }

  Future<void> _extractZip(List<int> bytes, String targetPath, InstallationLogCallback? onLog) async {
    final archive = ZipDecoder().decodeBytes(bytes);
    for (final file in archive) {
      final filename = file.name;
      if (onLog != null) onLog('Extracting: $filename');
      if (file.isFile) {
        final data = file.content as List<int>;
        final f = File(p.join(targetPath, filename));
        await f.create(recursive: true);
        await f.writeAsBytes(data);
      } else {
        await Directory(p.join(targetPath, filename)).create(recursive: true);
      }
    }
  }

  Future<void> _extractTarGz(List<int> bytes, String targetPath, InstallationLogCallback? onLog) async {
    final tarBytes = GZipDecoder().decodeBytes(bytes);
    final archive = TarDecoder().decodeBytes(tarBytes);
    for (final file in archive) {
      final filename = file.name;
      if (onLog != null) onLog('Extracting: $filename');
      if (file.isFile) {
        final data = file.content as List<int>;
        final f = File(p.join(targetPath, filename));
        await f.create(recursive: true);
        await f.writeAsBytes(data);
      } else {
        await Directory(p.join(targetPath, filename)).create(recursive: true);
      }
    }
  }

  Future<void> _flattenDirectory(String targetPath, Function(String) logInfo) async {
    final dir = Directory(targetPath);
    if (!dir.existsSync()) return;

    final entities = await dir.list().toList();
    
    // Check if there is only 1 entity and it's a directory
    if (entities.length == 1 && entities.first is Directory) {
      final subDir = entities.first as Directory;
      logInfo('Detected nested directory: ${p.basename(subDir.path)}. Flattening...');
      
      final subEntities = await subDir.list().toList();
      
      for (final entity in subEntities) {
        final newPath = p.join(targetPath, p.basename(entity.path));
        // Using rename might fail across different partitions, but here it's same parent
        await entity.rename(newPath);
      }
      
      // Delete the now empty nested directory
      await subDir.delete();
      logInfo('Flattening completed.');
    }
  }

  Future<Map<String, String?>> _detectFiles(
    String installPath,
    String? execName,
    String? cliName,
    Function(String) logInfo,
  ) async {
    final result = <String, String?>{
      'exec': null,
      'cli': null,
    };

    if (execName == null && cliName == null) return result;

    final dir = Directory(installPath);
    if (!dir.existsSync()) return result;

    try {
      final entities = await dir.list(recursive: true).toList();

      for (final entity in entities) {
        if (entity is File) {
          final filename = p.basename(entity.path);
          
          if (execName != null && filename == execName && result['exec'] == null) {
            result['exec'] = entity.path;
            logInfo('Detected executable: ${entity.path}');
          }
          
          if (cliName != null && filename == cliName && result['cli'] == null) {
            result['cli'] = entity.path;
            logInfo('Detected CLI: ${entity.path}');
          }
        }
      }
    } catch (e) {
      logInfo('Error during file detection: $e');
    }

    return result;
  }

  Future<void> delete(String path) async {
    final directory = Directory(path);
    if (directory.existsSync()) {
      _logger.info('Deleting directory: $path');
      await directory.delete(recursive: true);
    }
  }
}
