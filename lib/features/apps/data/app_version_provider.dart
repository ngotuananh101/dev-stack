import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'apps_provider.dart';

part 'app_version_provider.g.dart';

class AppVersionInfo {
  final String name;
  final List<String> versions;
  final Map<String, String> downloadUrls;
  final String? latestVersion;

  const AppVersionInfo({
    required this.name,
    required this.versions,
    required this.downloadUrls,
    this.latestVersion,
  });
}

@riverpod
class AppVersions extends _$AppVersions {
  @override
  Future<AppVersionInfo> build(String appId) async {
    return await _loadVersions(appId);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _loadVersions(appId));
  }

  Future<AppVersionInfo> _loadVersions(String appId) async {
    // 1. Get apps from the main provider
    final appsAsync = await ref.read(appsNotifierProvider.future);
    final app = appsAsync.firstWhere((a) => a.appId == appId, orElse: () => throw Exception('App not found'));

    // 2. Extract versions and links from the app model
    final versions = app.versions;
    final links = app.versionLinks;

    return AppVersionInfo(
      name: app.name,
      versions: versions,
      downloadUrls: links,
      latestVersion: versions.isNotEmpty ? versions.first : null,
    );
  }
}
