import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The JDK is a ~200 MB archive per version, so a catalog entry that points at
/// the wrong build is expensive. These tests pin what the installer needs:
/// Temurin's own download URLs, the publisher's SHA-256, and a version key the
/// user can recognise next to `java -version`.
void main() {
  Future<Map<String, Map<String, dynamic>>> load(String file) async {
    final catalog = jsonDecode(await File(file).readAsString());
    final apps = (catalog['apps'] as List).cast<Map<String, dynamic>>();
    return {for (final app in apps) app['id'] as String: app};
  }

  /// Every supported release line: the LTS versions plus the current feature.
  const ltsKeys = ['25.', '21.', '17.', '11.'];

  void expectSupportedLines(Iterable<String> versions) {
    for (final prefix in ltsKeys) {
      expect(
        versions.any((v) => v.startsWith(prefix)),
        isTrue,
        reason: 'every LTS is still installable, so ${prefix}x must be listed',
      );
    }
    expect(
      versions.contains('8.0.512') || versions.any((v) => v.startsWith('8.0.')),
      isTrue,
      reason: 'JDK 8 ships as 8uN, keyed here as 8.0.N',
    );
  }

  group('Windows catalog', () {
    test('Java is installable with verifiable Temurin zips', () async {
      final java = (await load('assets/data/apps.json'))['java'];

      expect(java, isNotNull, reason: 'Java must be in the Windows catalog');
      expect(java!['name'], 'Java');
      expect(java['category'], 'runtime');
      expect(java['group_name'], 'java');
      expect(java['exec_file'], 'java.exe');
      expect(java['cli_file'], 'javac.exe');

      final versions = java['versions'] as Map<String, dynamic>;
      final sha256 = java['sha256'] as Map<String, dynamic>;
      expect(versions, isNotEmpty);
      expect(sha256.keys.toSet(), versions.keys.toSet());
      expectSupportedLines(versions.keys);
      for (final entry in versions.entries) {
        expect(
          entry.value,
          matches(
            RegExp(
              r'^https://github\.com/adoptium/temurin\d+-binaries/releases/'
              r'download/[^/]+/OpenJDK\d+U-jdk_x64_windows_hotspot_[^/]+\.zip$',
            ),
          ),
          reason: entry.key,
        );
        expect(sha256[entry.key], matches(RegExp(r'^[a-f0-9]{64}$')));
      }
    });
  });

  group('Linux catalog', () {
    test('Java is installable with verifiable Temurin tarballs', () async {
      final java = (await load('assets/data/apps-linux.json'))['java'];

      expect(java, isNotNull, reason: 'Java must be in the Linux catalog');
      expect(java!['exec_file'], 'java');
      expect(java['cli_file'], 'javac');

      final versions = java['versions'] as Map<String, dynamic>;
      final sha256 = java['sha256'] as Map<String, dynamic>;
      expect(versions, isNotEmpty);
      expect(sha256.keys.toSet(), versions.keys.toSet());
      expectSupportedLines(versions.keys);
      for (final entry in versions.entries) {
        expect(
          entry.value,
          matches(
            RegExp(
              r'^https://github\.com/adoptium/temurin\d+-binaries/releases/'
              r'download/[^/]+/OpenJDK\d+U-jdk_x64_linux_hotspot_[^/]+\.tar\.gz$',
            ),
          ),
          reason: entry.key,
        );
        expect(sha256[entry.key], matches(RegExp(r'^[a-f0-9]{64}$')));
      }
    });

    test('Java ships one entry per release line, not one per patch', () async {
      final java = (await load('assets/data/apps-linux.json'))['java']!;
      final versions = java['versions'] as Map<String, dynamic>;

      // One app holding every JDK line means the list must stay short enough
      // to browse: a handful of supported lines, not every build ever cut.
      expect(versions.length, lessThan(12));
    });
  });

  group('brand assets', () {
    test('the JDK icon ships with the other runtime icons', () {
      final icon = File('assets/images/java.png');
      expect(icon.existsSync(), isTrue, reason: '${icon.path} is missing');
      expect(
        icon.lengthSync(),
        greaterThan(1000),
        reason: '${icon.path} looks like a placeholder',
      );
    });
  });
}
