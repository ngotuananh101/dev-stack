import 'dart:io';
import '../services/log_service.dart';

class AppConfig {
  static String _baseDir = 'C:\\Ponta';

  /// Default base directory value.
  static const String defaultBaseDir = 'C:\\Ponta';

  /// Initialize config from persisted settings. Call once at app startup.
  static void initialize({String? baseDir}) {
    if (baseDir != null && baseDir.isNotEmpty) {
      _baseDir = baseDir;
    }
  }

  /// The base directory for all Ponta data and applications.
  static String get baseDir => _baseDir;

  /// Directory where applications are installed.
  static String get appsDir => '$_baseDir\\apps';

  /// Directory for system binaries and tools.
  static String get binDir => '$_baseDir\\bin';

  /// Directory for system and service logs.
  static String get logsDir => '$_baseDir\\logs';

  /// Directory for webserver roots.
  static String get webserverRoot => '$_baseDir\\www';

  /// Certificates directory.
  static String get certsDir => '$_baseDir\\certs';

  /// Vhosts directory.
  static String get vhostsDir => '$_baseDir\\vhosts';

  /// SQL databases directory.
  static String get dataDir => '$_baseDir\\data';
}

/// Update DEVSTACK_BASE_DIR environment variable in Windows registry.
Future<void> updateBaseDirEnvVar(String baseDir) async {
  try {
    final result = await Process.run('powershell', [
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
  } catch (e) {
    AppLogger.warning('Failed to update DEVSTACK_BASE_DIR: $e');
  }
}
