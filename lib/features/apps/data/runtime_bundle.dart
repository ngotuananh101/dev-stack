import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

class RuntimeBundleManifest {
  final String root;
  final String runtime;
  final String version;
  final Set<String> launchers;

  RuntimeBundleManifest({
    required this.root,
    required this.runtime,
    required this.version,
    required this.launchers,
  });

  /// Loads the runtime manifest from [root].
  ///
  /// Returns `null` when the manifest is absent, not valid JSON, not schema_version 1,
  /// the runtime is not 'apache' or 'postgresql', or required version/launcher keys are missing.
  static RuntimeBundleManifest? load(String root) {
    try {
      final manifestFile = File(p.join(root, 'manifest.json'));
      if (!manifestFile.existsSync()) {
        return null;
      }

      final content = manifestFile.readAsStringSync();
      final data = jsonDecode(content);
      if (data is! Map) {
        return null;
      }

      if (data['schema_version'] != 1) {
        return null;
      }

      final runtime = data['runtime'];
      if (runtime != 'apache' && runtime != 'postgresql') {
        return null;
      }

      final runtimeData = data[runtime];
      if (runtimeData is! Map) {
        return null;
      }

      final version = runtimeData['version'];
      if (version is! String || !RegExp(r'^\d+(\.\d+)+$').hasMatch(version)) {
        return null;
      }

      final launchers = <String>{};
      if (runtime == 'apache') {
        final list = data['launchers'];
        if (list is! List) return null;
        for (final item in list) {
          if (item is String && item.isNotEmpty) {
            launchers.add(item);
          }
        }
      } else if (runtime == 'postgresql') {
        final list = data['binaries'];
        if (list is! List) return null;
        for (final item in list) {
          if (item is Map) {
            final path = item['path'];
            if (path is String && path.isNotEmpty) {
              launchers.add(p.basename(path));
            }
          }
        }
      }

      final canonicalRoot = Directory(root).resolveSymbolicLinksSync();

      return RuntimeBundleManifest(
        root: canonicalRoot,
        runtime: runtime,
        version: version,
        launchers: launchers,
      );
    } catch (_) {
      return null;
    }
  }

  /// Whether the manifest declared a launcher with [name].
  bool declaresLauncher(String name) => launchers.contains(name);

  /// Resolves the path to `<root>/bin/<name>`.
  ///
  /// Throws [ArgumentError] if [name] is not declared by the manifest.
  String launcherPath(String name) {
    if (!declaresLauncher(name)) {
      throw ArgumentError(
        'Launcher "$name" is not declared by $runtime manifest.',
      );
    }
    return p.join(root, 'bin', name);
  }
}
