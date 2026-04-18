import 'dart:convert';
import 'package:isar/isar.dart';

part 'app_model.g.dart';

@collection
class AppModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String appId; // From JSON "id"

  late String name;
  late String? description;
  late String developer;
  late List<String> categories;
  late String groupName;
  late String execFile;
  late String cliFile;

  late List<String> versions; // Available versions for installation
  
  // Isar does not support Map directly, so we store links as a JSON string
  late String? versionLinksJson; 

  @ignore
  Map<String, String> get versionLinks {
    if (versionLinksJson == null) return {};
    try {
      final decoded = json.decode(versionLinksJson!) as Map<String, dynamic>;
      return decoded.map((key, value) => MapEntry(key, value.toString()));
    } catch (_) {
      return {};
    }
  }

  set versionLinks(Map<String, String> links) {
    versionLinksJson = json.encode(links);
  }

  late String? selectedVersion; // Currently selected version

  late double? price; // null = Free
  late String? expireDate; // e.g., "Perpetual"
  late String? location;
  late String? status; // e.g., "running", "stopped"
  late bool displayOnDashboard;

  @Index()
  late bool isInstalled;

  AppModel({
    this.id = Isar.autoIncrement,
    required this.appId,
    required this.name,
    this.description,
    this.developer = 'official',
    required this.categories,
    required this.groupName,
    required this.execFile,
    required this.cliFile,
    this.versions = const ['latest'],
    this.versionLinksJson,
    this.selectedVersion,
    this.price,
    this.expireDate,
    this.location,
    this.status,
    this.displayOnDashboard = false,
    this.isInstalled = false,
  });
}
