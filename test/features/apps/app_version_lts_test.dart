import 'package:dev_stack/features/apps/data/app_version_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppVersionInfo LTS helpers', () {
    test('reports LTS only when labels come from metadata/API', () {
      const info = AppVersionInfo(
        name: 'Node.js',
        versions: ['25.9.0', '24.15.0', '22.22.2'],
        downloadUrls: {},
        latestVersion: '25.9.0',
        ltsLabels: {'24.15.0': 'Krypton', '22.22.2': 'Jod'},
      );

      // Latest/current is not LTS just because it is first.
      expect(info.latestVersion, '25.9.0');
      expect(info.isLts('25.9.0'), isFalse);
      expect(info.ltsLabel('25.9.0'), isNull);

      // Only API/catalog-provided LTS versions are tagged.
      expect(info.isLts('24.15.0'), isTrue);
      expect(info.ltsLabel('24.15.0'), 'Krypton');
      expect(info.isLts('22.22.2'), isTrue);
      expect(info.ltsLabel('22.22.2'), 'Jod');
    });
  });

  group('AppVersions.filterCurrentLts', () {
    final now = DateTime(2026, 8, 15);

    test('keeps only LTS lines whose support has not ended', () {
      final result = AppVersions.filterCurrentLts(
        {
          '18.20.8': 'Hydrogen',
          '20.19.4': 'Iron',
          '22.22.2': 'Jod',
          '24.15.0': 'Krypton',
        },
        {
          'v18': {'end': '2025-04-30'},
          'v20': {'end': '2026-04-30'},
          'v22': {'end': '2027-04-30'},
          'v24': {'end': '2028-04-30'},
        },
        now: now,
      );

      expect(result, {'22.22.2': 'Jod', '24.15.0': 'Krypton'});
    });

    test(
      'keeps a line ending today and drops majors missing from schedule',
      () {
        final result = AppVersions.filterCurrentLts(
          {'6.17.1': 'Boron', '22.22.2': 'Jod'},
          {
            'v22': {'end': '2026-08-15'},
          },
          now: now,
        );

        expect(result, {'22.22.2': 'Jod'});
      },
    );

    test('falls back to the newest LTS major when schedule is unavailable', () {
      final result = AppVersions.filterCurrentLts(
        {'18.20.8': 'Hydrogen', '22.22.2': 'Jod', '24.15.0': 'Krypton'},
        null,
        now: now,
      );

      expect(result, {'24.15.0': 'Krypton'});
    });

    test('returns empty for empty labels', () {
      expect(AppVersions.filterCurrentLts({}, null, now: now), isEmpty);
      expect(AppVersions.filterCurrentLts({}, {}, now: now), isEmpty);
    });
  });
}
