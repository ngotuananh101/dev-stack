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
