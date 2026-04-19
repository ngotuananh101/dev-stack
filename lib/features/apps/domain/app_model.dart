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
  String? execFilePath;
  String? cliFilePath;
  bool isAddedToPath;
  bool addPathAfterInstall;

  // Real-time progress (non-persistent)
  double? installProgress;
  String? installStatus;
  int? downloadedBytes;
  int? totalBytes;
  List<String> installLogs = [];

  void addLog(String message) {
    installLogs.add(message);
    if (installLogs.length > 50) installLogs.removeAt(0);
  }

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

  bool get hasUpdateAvailable {
    if (!isInstalled || installedVersion == null || versions.isEmpty) return false;

    // Split installed version to get Major.Minor (e.g., 8.2 from 8.2.1)
    final parts = installedVersion!.split('.');
    if (parts.length < 2) return false;
    final baseVersion = '${parts[0]}.${parts[1]}';

    for (final v in versions) {
      if (v == 'latest') continue;
      if (v == installedVersion) continue;

      // Check if version belongs to the same Major.Minor branch
      if (v.startsWith('$baseVersion.')) {
        if (isVersionNewer(v, installedVersion!)) {
          return true;
        }
      }
    }
    return false;
  }

  bool isVersionNewer(String newV, String oldV) {
    final newParts = newV.split('.');
    final oldParts = oldV.split('.');

    for (var i = 0; i < newParts.length && i < oldParts.length; i++) {
      final n = int.tryParse(newParts[i]) ?? 0;
      final o = int.tryParse(oldParts[i]) ?? 0;
      if (n > o) return true;
      if (n < o) return false;
    }
    return newParts.length > oldParts.length;
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
    this.execFilePath,
    this.cliFilePath,
    this.isAddedToPath = false,
    this.addPathAfterInstall = false,
    this.installProgress,
    this.installStatus,
  });
}
