import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'apps_provider.dart';

part 'app_version_provider.g.dart';

class AppVersionInfo {
  final String name;
  final List<String> versions;
  final Map<String, String> downloadUrls;
  final String? latestVersion;

  /// LTS codename/label by version from catalog or Node.js release API.
  /// Example: `24.15.0 -> "Krypton"`. Latest/current releases are not LTS.
  final Map<String, String> ltsLabels;

  const AppVersionInfo({
    required this.name,
    required this.versions,
    required this.downloadUrls,
    this.latestVersion,
    this.ltsLabels = const {},
  });

  bool isLts(String version) => ltsLabels.containsKey(version);

  String? ltsLabel(String version) => ltsLabels[version];
}

@riverpod
class AppVersions extends _$AppVersions {
  static const _nodeReleaseIndexUrl =
      'https://nodejs.org/download/release/index.json';

  @override
  Future<AppVersionInfo> build(String appId) async {
    return await _loadVersions(appId);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _loadVersions(appId));
  }

  Future<AppVersionInfo> _loadVersions(String appId) async {
    final appsAsync = await ref.read(appsNotifierProvider.future);
    final app = appsAsync.firstWhere(
      (a) => a.appId == appId,
      orElse: () => throw Exception('App not found'),
    );

    final versions = app.versions;
    final links = app.versionLinks;
    final ltsLabels = await _resolveLtsLabels(
      app.appId,
      versions,
      app.extraInfo,
    );

    return AppVersionInfo(
      name: app.name,
      versions: versions,
      downloadUrls: links,
      latestVersion: versions.isNotEmpty ? versions.first : null,
      ltsLabels: ltsLabels,
    );
  }

  /// LTS labels come from real metadata only:
  /// 1. Node.js release API for Node apps (source of truth)
  /// 2. Catalog `lts` / `lts_labels` as offline fallback
  ///
  /// Never infer LTS from "latest" or even major numbers.
  Future<Map<String, String>> _resolveLtsLabels(
    String appId,
    List<String> versions,
    Map<String, dynamic> extraInfo,
  ) async {
    final isNodeApp =
        appId.toLowerCase().contains('nodejs') ||
        appId.toLowerCase() == 'node';

    if (isNodeApp) {
      final apiLabels = await _fetchNodeLtsLabelsFromApi(versions);
      if (apiLabels.isNotEmpty) {
        return apiLabels;
      }
    }

    return _catalogLtsLabels(extraInfo);
  }

  Map<String, String> _catalogLtsLabels(Map<String, dynamic> extraInfo) {
    final labels = <String, String>{};

    final rawLabels = extraInfo['lts_labels'];
    if (rawLabels is Map) {
      rawLabels.forEach((key, value) {
        final version = key.toString();
        final label = value?.toString().trim();
        if (version.isNotEmpty && label != null && label.isNotEmpty) {
          labels[version] = label;
        }
      });
    }

    final rawLts = extraInfo['lts'];
    if (rawLts is List) {
      for (final item in rawLts) {
        final version = item.toString();
        labels.putIfAbsent(version, () => 'LTS');
      }
    } else if (rawLts is Map) {
      rawLts.forEach((key, value) {
        final version = key.toString();
        final label = value?.toString().trim();
        labels.putIfAbsent(
          version,
          () => (label != null && label.isNotEmpty) ? label : 'LTS',
        );
      });
    }

    return labels;
  }

  Future<Map<String, String>> _fetchNodeLtsLabelsFromApi(
    List<String> knownVersions,
  ) async {
    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 20),
        ),
      );
      final response = await dio.get<List<dynamic>>(_nodeReleaseIndexUrl);
      final data = response.data;
      if (data == null) return {};

      final known = knownVersions.toSet();
      final labels = <String, String>{};

      for (final item in data) {
        if (item is! Map) continue;
        final versionRaw = item['version']?.toString() ?? '';
        if (versionRaw.isEmpty) continue;
        final version = versionRaw.startsWith('v')
            ? versionRaw.substring(1)
            : versionRaw;

        // Only attach labels for versions present in the app catalog.
        if (known.isNotEmpty && !known.contains(version)) continue;

        final lts = item['lts'];
        if (lts is String && lts.trim().isNotEmpty) {
          labels[version] = lts.trim();
        } else if (lts == true) {
          labels[version] = 'LTS';
        }
      }

      return labels;
    } catch (_) {
      // Offline / network failure: caller falls back to catalog metadata.
      return {};
    }
  }
}
