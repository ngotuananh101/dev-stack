import 'app_model.dart';

abstract final class AppConflictPolicy {
  static const Map<String, Set<String>> _conflicts = {
    'mysql': {'mariadb'},
    'mariadb': {'mysql'},
    'nginx': {'apache', 'caddy'},
    'apache': {'nginx', 'caddy'},
    'caddy': {'nginx', 'apache'},
  };

  static Set<String> conflictsFor(AppModel app) {
    final appId = app.appId.toLowerCase();
    final groupName = app.groupName?.toLowerCase() ?? '';
    for (final entry in _conflicts.entries) {
      if (appId.contains(entry.key) || groupName.contains(entry.key)) {
        return entry.value;
      }
    }
    return const <String>{};
  }

  static AppModel? firstInstalledConflict(
    AppModel target,
    Iterable<AppModel> apps,
  ) {
    final patterns = conflictsFor(target);
    if (patterns.isEmpty) return null;

    for (final candidate in apps) {
      if (!candidate.isInstalled || candidate.appId == target.appId) continue;
      final id = candidate.appId.toLowerCase();
      final group = candidate.groupName?.toLowerCase() ?? '';
      if (patterns.any(
        (pattern) => id.contains(pattern) || group.contains(pattern),
      )) {
        return candidate;
      }
    }
    return null;
  }
}
