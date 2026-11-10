import 'dart:io';
import 'package:flutter/foundation.dart' show visibleForTesting;

/// Utility to detect Linux distribution info and resolve
/// distro-specific download URL placeholders (e.g. `{mongo_distro}`, `{version_id}`)
/// based on `/etc/os-release`.
class LinuxDistroResolver {
  /// Parses `/etc/os-release` key-value pairs.
  @visibleForTesting
  static Map<String, String> parseOsRelease(String content) {
    final map = <String, String>{};
    for (final line in content.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final eqIdx = trimmed.indexOf('=');
      if (eqIdx > 0) {
        final key = trimmed.substring(0, eqIdx).trim();
        var val = trimmed.substring(eqIdx + 1).trim();
        if ((val.startsWith('"') && val.endsWith('"')) ||
            (val.startsWith("'") && val.endsWith("'"))) {
          val = val.substring(1, val.length - 1);
        }
        map[key] = val;
      }
    }
    return map;
  }

  /// Detects the distro codename (e.g. noble, jammy, focal, bookworm).
  static String _detectCodename({String? osReleaseContent, bool? isLinux}) {
    final linux = isLinux ?? Platform.isLinux;
    if (!linux) return 'jammy';

    try {
      String content = osReleaseContent ?? '';
      if (osReleaseContent == null) {
        final file = File('/etc/os-release');
        if (file.existsSync()) {
          content = file.readAsStringSync();
        }
      }

      if (content.isNotEmpty) {
        final parsed = parseOsRelease(content);
        final codename =
            parsed['VERSION_CODENAME'] ?? parsed['UBUNTU_CODENAME'];
        if (codename != null && codename.isNotEmpty) {
          return codename.toLowerCase();
        }

        // Check ID or ID_LIKE (e.g. debian, fedora, arch)
        final id = (parsed['ID'] ?? '').toLowerCase();
        final idLike = (parsed['ID_LIKE'] ?? '').toLowerCase();
        if (id == 'debian' || idLike.contains('debian')) {
          final verId = parsed['VERSION_ID'] ?? '';
          if (verId.startsWith('12')) return 'bookworm';
          if (verId.startsWith('11')) return 'bullseye';
          if (verId.startsWith('13')) return 'trixie';
        }
      }
    } catch (_) {}

    return 'jammy'; // Safe modern LTS default (glibc 2.35)
  }

  /// Maps detected distro codename to the best available MongoDB distribution target.
  @visibleForTesting
  static String resolveMongoDistro({String? osReleaseContent, bool? isLinux}) {
    final codename = _detectCodename(
      osReleaseContent: osReleaseContent,
      isLinux: isLinux,
    );

    switch (codename) {
      case 'noble':
        return 'ubuntu2404';
      case 'focal':
        return 'ubuntu2004';
      case 'bookworm':
        return 'debian12';
      case 'jammy':
      default:
        return 'ubuntu2204';
    }
  }

  /// Detects the distro version ID (e.g. 41, 40, 12, 24.04).
  static String detectVersionId({String? osReleaseContent, bool? isLinux}) {
    final linux = isLinux ?? Platform.isLinux;
    if (!linux) return '41';

    try {
      String content = osReleaseContent ?? '';
      if (osReleaseContent == null) {
        final file = File('/etc/os-release');
        if (file.existsSync()) {
          content = file.readAsStringSync();
        }
      }

      if (content.isNotEmpty) {
        final parsed = parseOsRelease(content);
        final versionId = parsed['VERSION_ID'];
        if (versionId != null && versionId.isNotEmpty) {
          return versionId;
        }
      }
    } catch (_) {}

    return '41';
  }

  /// Resolves any template placeholders in download URLs:
  /// - `{mongo_distro}` -> `ubuntu2404` / `ubuntu2204` / `ubuntu2004` / `debian12`
  /// - `{version_id}` -> `41` / `40` / `12` / `24.04`
  static String resolveUrl(
    String url, {
    String? osReleaseContent,
    bool? isLinux,
  }) {
    if (!url.contains('{')) return url;

    final mongoDistro = resolveMongoDistro(
      osReleaseContent: osReleaseContent,
      isLinux: isLinux,
    );
    final versionId = detectVersionId(
      osReleaseContent: osReleaseContent,
      isLinux: isLinux,
    );

    var resolved = url
        .replaceAll('{mongo_distro}', mongoDistro)
        .replaceAll('{version_id}', versionId);

    return resolved;
  }
}
