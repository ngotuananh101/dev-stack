import 'package:isar/isar.dart';

part 'app_settings.g.dart';

@collection
class AppSettings {
  Id id = Isar.autoIncrement;

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

  AppSettings();
}
