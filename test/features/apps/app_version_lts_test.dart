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
        ltsLabels: {
          '24.15.0': 'Krypton',
          '22.22.2': 'Jod',
        },
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
}
