import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Go and Flutter are multi-gigabyte SDK archives, so a catalog entry that is
/// wrong is expensive: the user pays the download before anything fails. These
/// tests pin what the installer needs to find and verify.
void main() {
  Future<Map<String, Map<String, dynamic>>> load(String file) async {
    final catalog = jsonDecode(await File(file).readAsString());
    final apps = (catalog['apps'] as List).cast<Map<String, dynamic>>();
    return {for (final app in apps) app['id'] as String: app};
  }

  group('Windows catalog', () {
    test('Go is installable with verifiable amd64 zips', () async {
      final go = (await load('assets/data/apps.json'))['go']!;

      expect(go['name'], 'Go');
      expect(go['category'], 'runtime');
      expect(go['group_name'], 'go');
      expect(go['exec_file'], 'go.exe');
      expect(go['cli_file'], 'go.exe');

      final versions = go['versions'] as Map<String, dynamic>;
      final sha256 = go['sha256'] as Map<String, dynamic>;
      expect(versions, isNotEmpty);
      expect(
        versions.keys.every((v) => RegExp(r'^\d+\.\d+\.\d+$').hasMatch(v)),
        isTrue,
      );
      for (final entry in versions.entries) {
        expect(
          entry.value,
          matches(RegExp(r'^https://go\.dev/dl/go[\d.]+\.windows-amd64\.zip$')),
        );
        expect(sha256[entry.key], matches(RegExp(r'^[a-f0-9]{64}$')));
      }
    });

    test('Flutter is installable with verifiable Windows zips', () async {
      final flutter = (await load('assets/data/apps.json'))['flutter']!;

      expect(flutter['name'], 'Flutter');
      expect(flutter['category'], 'runtime');
      expect(flutter['group_name'], 'flutter');
      expect(flutter['exec_file'], 'flutter.bat');
      expect(flutter['cli_file'], 'dart.bat');

      final versions = flutter['versions'] as Map<String, dynamic>;
      final sha256 = flutter['sha256'] as Map<String, dynamic>;
      expect(versions, isNotEmpty);
      for (final entry in versions.entries) {
        expect(
          entry.value,
          matches(
            RegExp(
              r'^https://storage\.googleapis\.com/flutter_infra_release/'
              r'releases/stable/windows/flutter_windows_[\d.]+-stable\.zip$',
            ),
          ),
        );
        expect(sha256[entry.key], matches(RegExp(r'^[a-f0-9]{64}$')));
      }
    });
  });

  group('Linux catalog', () {
    test('Go is installable with verifiable amd64 tarballs', () async {
      final go = (await load('assets/data/apps-linux.json'))['go']!;

      expect(go['exec_file'], 'go');
      expect(go['cli_file'], 'go');

      final versions = go['versions'] as Map<String, dynamic>;
      final sha256 = go['sha256'] as Map<String, dynamic>;
      expect(versions, isNotEmpty);
      for (final entry in versions.entries) {
        expect(
          entry.value,
          matches(
            RegExp(r'^https://go\.dev/dl/go[\d.]+\.linux-amd64\.tar\.gz$'),
          ),
        );
        expect(sha256[entry.key], matches(RegExp(r'^[a-f0-9]{64}$')));
      }
    });

    test('Flutter is installable with verifiable tar.xz archives', () async {
      final flutter = (await load('assets/data/apps-linux.json'))['flutter']!;

      expect(flutter['exec_file'], 'flutter');
      expect(flutter['cli_file'], 'dart');

      final versions = flutter['versions'] as Map<String, dynamic>;
      final sha256 = flutter['sha256'] as Map<String, dynamic>;
      expect(versions, isNotEmpty);
      for (final entry in versions.entries) {
        expect(
          entry.value,
          matches(
            RegExp(
              r'^https://storage\.googleapis\.com/flutter_infra_release/'
              r'releases/stable/linux/flutter_linux_[\d.]+-stable\.tar\.xz$',
            ),
          ),
        );
        expect(sha256[entry.key], matches(RegExp(r'^[a-f0-9]{64}$')));
      }
    });

    test('both SDKs stay within a usable version count', () async {
      // The updater keeps the newest patch of every minor; publishing every
      // patch ever cut would quadruple both payload lists for no benefit.
      final apps = await load('assets/data/apps-linux.json');
      for (final id in ['go', 'flutter']) {
        final versions = apps[id]!['versions'] as Map<String, dynamic>;
        expect(versions.length, lessThan(40), reason: id);
      }
    });
  });

  group('brand assets', () {
    test('an icon file exists for each SDK', () {
      for (final name in ['go', 'flutter']) {
        final icon = File('assets/images/$name.png');
        expect(icon.existsSync(), isTrue, reason: '${icon.path} is missing');
        expect(
          icon.lengthSync(),
          greaterThan(1000),
          reason: '${icon.path} looks like a placeholder',
        );      }
    });
  });
}
