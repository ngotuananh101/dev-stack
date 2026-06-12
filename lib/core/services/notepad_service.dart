import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:dev_stack/core/config/app_config.dart';
import 'package:dev_stack/core/services/log_service.dart';

class NotepadService {
  /// Resolve Notepad++ executable path.
  /// Checks: binDir → dev assets → prod assets (next to executable).
  static String? get notepadPath {
    // 1. Installed in Ponta bin directory
    final binPath = p.join(AppConfig.binDir, 'npp', 'notepad++.exe');
    if (File(binPath).existsSync()) return binPath;

    // 2. Dev mode: assets/bin/npp/
    final devPath = p.join(
      Directory.current.path,
      'assets',
      'bin',
      'npp',
      'notepad++.exe',
    );
    if (File(devPath).existsSync()) return devPath;

    // 3. Prod mode: next to executable
    final prodPath = p.join(
      p.dirname(Platform.resolvedExecutable),
      'data',
      'flutter_assets',
      'assets',
      'bin',
      'npp',
      'notepad++.exe',
    );
    if (File(prodPath).existsSync()) return prodPath;

    AppLogger.error('Notepad++ not found in any expected location');
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
