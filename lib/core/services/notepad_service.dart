import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:dev_stack/core/config/app_config.dart';
import 'package:dev_stack/core/services/log_service.dart';

class NotepadService {
  /// Ensure Notepad++ is extracted to AppConfig.binDir/npp/
  /// Call this once at app startup
  static Future<void> ensureExtracted() async {
    final nppDir = p.join(AppConfig.binDir, 'npp');
    final nppExe = p.join(nppDir, 'notepad++.exe');

    // Already extracted
    if (File(nppExe).existsSync()) {
      AppLogger.info('Notepad++ already extracted at $nppDir');
      return;
    }

    // Create bin directory if not exists
    final binDir = Directory(AppConfig.binDir);
    if (!binDir.existsSync()) {
      binDir.createSync(recursive: true);
    }

    // Copy npp.zip from assets to binDir
    final zipPath = p.join(AppConfig.binDir, 'npp.zip');
    try {
      AppLogger.info('Extracting Notepad++ from assets...');
      final zipData = await rootBundle.load('assets/bin/npp.zip');
      final zipBytes = zipData.buffer.asUint8List();
      await File(zipPath).writeAsBytes(zipBytes);

      // Extract zip into npp/ subdirectory
      Directory(nppDir).createSync(recursive: true);
      final archive = ZipDecoder().decodeBytes(zipBytes);
      for (final file in archive) {
        final filename = file.name;
        if (file.isFile) {
          final data = file.content as List<int>;
          final outFile = File(p.join(nppDir, filename));
          await outFile.parent.create(recursive: true);
          await outFile.writeAsBytes(data);
        } else {
          final dir = Directory(p.join(nppDir, filename));
          await dir.create(recursive: true);
        }
      }

      // Delete zip file
      await File(zipPath).delete();
      AppLogger.info('Notepad++ extracted successfully to $nppDir');
    } catch (e) {
      AppLogger.error('Failed to extract Notepad++: $e');
      // Clean up partial extraction
      if (File(zipPath).existsSync()) {
        await File(zipPath).delete();
      }
    }
  }

  /// Resolve Notepad++ executable path.
  static String? get notepadPath {
    // Dev mode: check source assets/bin/npp/ first
    final devPath = p.join(
      Directory.current.path,
      'assets',
      'bin',
      'npp',
      'notepad++.exe',
    );
    if (File(devPath).existsSync()) return devPath;

    // Installed: AppConfig.binDir/npp/ (extracted from npp.zip at startup)
    final binPath = p.join(AppConfig.binDir, 'npp', 'notepad++.exe');
    if (File(binPath).existsSync()) return binPath;

    AppLogger.error('Notepad++ not found');
    return null;
  }

  /// Open a file in Notepad++ and wait until the user closes it.
  /// Returns true if NPP was launched successfully.
  static Future<bool> openFile(String filePath) async {
    final npp = notepadPath;
    if (npp == null) return false;

    final file = File(filePath);
    if (!await file.exists()) {
      AppLogger.error('Config file not found: $filePath');
      return false;
    }

    try {
      AppLogger.info('Opening $filePath in Notepad++');
      final process = await Process.start(npp, [filePath]);
      // Wait for the user to close Notepad++
      await process.exitCode;
      AppLogger.info('Notepad++ closed for $filePath');
      return true;
    } catch (e) {
      AppLogger.error('Failed to launch Notepad++: $e');
      return false;
    }
  }
}
