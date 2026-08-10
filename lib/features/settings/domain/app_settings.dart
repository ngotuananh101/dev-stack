import 'package:isar/isar.dart';

part 'app_settings.g.dart';

@collection
class AppSettings {
  Id id = 0;

  // Base Directory
  String baseDir = 'C:\\Ponta';

  // Site Configuration
  String siteTemplate = '[site-name].test';
  bool autoCreateSite = false;

  // Application Behavior
  bool minimizeToTray = false;
  bool autoStartWithWindows = false;

  // SSL Configuration
  bool isSslInstalled = false;

  // Network: when true, webservers bind to 0.0.0.0 (reachable from the LAN).
  // Default false — bind to 127.0.0.1 only, so phpMyAdmin and dev sites are
  // not exposed to other machines on the network.
  bool allowLanAccess = false;

  AppSettings();
}
