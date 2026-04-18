import 'dart:convert';

class AppModel {
  final String appId;
  String name;
  String? description;
  String developer;
  List<String> categories;
  String? groupName;
  String? execFile;
  String? cliFile;
  List<String> versions;
  String? versionLinksJson;
  
  // UI/State properties
  String? selectedVersion;
  bool displayOnDashboard;

  // Installation state (merged from DB)
  String? location;
  String? status;
  String? installedVersion;
  bool isInstalled;
  DateTime? installedAt;

  // Real-time progress (non-persistent)
  double? installProgress;
  String? installStatus;

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

  AppModel({
    required this.appId,
    required this.name,
    this.description,
    this.developer = 'official',
    required this.categories,
    this.groupName,
    this.execFile,
    this.cliFile,
    this.versions = const ['latest'],
    this.versionLinksJson,
    this.selectedVersion,
    this.displayOnDashboard = false,
    this.location,
    this.status,
    this.installedVersion,
    this.isInstalled = false,
    this.installedAt,
    this.installProgress,
    this.installStatus,
  });
}
