import 'package:isar/isar.dart';

part 'installed_app.g.dart';

@collection
class InstalledApp {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String appId;

  late String appName;
  late String location;
  late String status; // 'running', 'stopped', 'installing', 'not_installed'
  
  String? version; // The version currently installed
  DateTime? installedAt;
  
  String? execFilePath;
  String? cliFilePath;

  InstalledApp({
    required this.appId,
    required this.appName,
    required this.location,
    required this.status,
    this.version,
    this.installedAt,
    this.execFilePath,
    this.cliFilePath,
  });
}
