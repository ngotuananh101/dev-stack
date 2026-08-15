import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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
  static const _nodeScheduleUrl =
      'https://raw.githubusercontent.com/nodejs/Release/main/schedule.json';

  @override
  Future<AppVersionInfo> build(String appId) async {
    return await _loadVersions(appId);
  }

  /// Keeps only LTS lines that are still current: a version stays tagged
  /// while its major's support window has not ended. Node.js keeps several
  /// majors in LTS at once (e.g. 22 and 24 in 2026), so this is per-major,
  /// not "latest LTS only".
  ///
  /// [schedule] maps major keys like `v22` to entries with an `end` date
  /// (nodejs/Release schedule.json). When it is null/empty (offline), the
  /// newest LTS major is kept as a best-effort fallback.
  @visibleForTesting
  static Map<String, String> filterCurrentLts(
    Map<String, String> labels,
    Map<String, dynamic>? schedule, {
    DateTime? now,
  }) {
    if (labels.isEmpty) return {};
    final today = now ?? DateTime.now();

    int? majorOf(String version) => int.tryParse(version.split('.').first);

    if (schedule == null || schedule.isEmpty) {
      final newest = labels.keys
          .map(majorOf)
          .whereType<int>()
          .fold<int?>(null, (a, b) => a == null || b > a ? b : a);
      if (newest == null) return labels;
      return Map.fromEntries(
        labels.entries.where((e) => majorOf(e.key) == newest),
      );
    }

    final endByMajor = <int, DateTime>{};
    schedule.forEach((key, value) {
      final major = int.tryParse(key.replaceFirst(RegExp(r'^v'), ''));
      final end = value is Map ? value['end']?.toString() : null;
      if (major == null || end == null || end.isEmpty) return;
      final parsed = DateTime.tryParse(end);
      if (parsed != null) endByMajor[major] = parsed;
    });

    return Map.fromEntries(
      labels.entries.where((e) {
        final major = majorOf(e.key);
        final end = major == null ? null : endByMajor[major];
        // Unknown majors (schedule gap) are dropped rather than guessed.
        return end != null && !today.isAfter(end);
      }),
    );
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
  /// Never infer LTS from "latest" or even major numbers. Labels are then
  /// narrowed to still-supported LTS lines via the Node.js release schedule,
  /// so EOL majors (e.g. Hydrogen/18 after 2025-04-30) stop showing a badge.
  Future<Map<String, String>> _resolveLtsLabels(
    String appId,
    List<String> versions,
    Map<String, dynamic> extraInfo,
  ) async {
    final isNodeApp =
        appId.toLowerCase().contains('nodejs') || appId.toLowerCase() == 'node';

    if (isNodeApp) {
      final apiLabels = await _fetchNodeLtsLabelsFromApi(versions);
      if (apiLabels.isNotEmpty) {
        final schedule = await _fetchNodeSchedule();
        return filterCurrentLts(apiLabels, schedule);
      }
    }

    return _catalogLtsLabels(extraInfo);
  }

  Future<Map<String, dynamic>?> _fetchNodeSchedule() async {
    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 20),
        ),
      );
      final response = await dio.get<Map<String, dynamic>>(_nodeScheduleUrl);
      return response.data;
    } catch (_) {
      // Offline: filterCurrentLts falls back to the newest LTS major.
      return null;
    }
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
