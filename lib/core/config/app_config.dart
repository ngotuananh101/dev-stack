import 'dart:io';
import 'package:path/path.dart' as p;
import '../services/background_process.dart';
import '../services/log_service.dart';

class AppConfig {
  static String _baseDir = defaultBaseDir;

  /// Default base directory value based on OS.
  static String get defaultBaseDir {
    if (Platform.isLinux) {
      final home = Platform.environment['HOME'] ?? '';
      return p.join(home, '.ponta');
    }
    return r'C:\Ponta';
  }

  /// Initialize config from persisted settings. Call once at app startup.
  static void initialize({String? baseDir}) {
    if (baseDir != null && baseDir.isNotEmpty) {
      _baseDir = baseDir;
    } else {
      _baseDir = defaultBaseDir;
    }
  }

  /// The base directory for all Ponta data and applications.
  static String get baseDir => _baseDir;

  /// Directory where applications are installed.
  static String get appsDir => p.join(_baseDir, 'apps');

  /// Directory for system binaries and tools.
  static String get binDir => p.join(_baseDir, 'bin');

  /// Directory for system and service logs.
  static String get logsDir => p.join(_baseDir, 'logs');

  /// Directory for webserver roots.
  static String get webserverRoot => p.join(_baseDir, 'www');

  /// Certificates directory.
  static String get certsDir => p.join(_baseDir, 'certs');

  /// Vhosts directory.
  static String get vhostsDir => p.join(_baseDir, 'vhosts');

  /// SQL databases directory.
  static String get dataDir => p.join(_baseDir, 'data');
}

/// Update DEVSTACK_BASE_DIR environment variable.
Future<void> updateBaseDirEnvVar(String baseDir) async {
  try {
    if (Platform.isWindows) {
      final result = await BackgroundProcess.run('powershell', [
        '-NoProfile',
        '-Command',
        r'[Environment]::SetEnvironmentVariable($args[0], $args[1], "User")',
        'DEVSTACK_BASE_DIR',
        baseDir,
      ]);

      if (result.exitCode == 0) {
        AppLogger.info(
          'Updated DEVSTACK_BASE_DIR environment variable: $baseDir',
        );
      } else {
        AppLogger.warning('Failed to update DEVSTACK_BASE_DIR: ${result.stderr}');
      }
    } else if (Platform.isLinux) {
      AppLogger.info('Base dir set to $baseDir');
    }
  } catch (e) {
    AppLogger.warning('Failed to update DEVSTACK_BASE_DIR: $e');
  }
}
