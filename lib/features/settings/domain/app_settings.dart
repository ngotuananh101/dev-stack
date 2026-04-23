import 'package:isar/isar.dart';

part 'app_settings.g.dart';

@collection
class AppSettings {
  Id id = Isar.autoIncrement;

  // Site Configuration
  String? defaultPhpVersion;
  String siteTemplate = '[site-name].test';
  bool autoCreateSite = false;

  // Application Behavior
  bool minimizeToTray = false;
  bool autoStartWithWindows = false;

  AppSettings();
}
