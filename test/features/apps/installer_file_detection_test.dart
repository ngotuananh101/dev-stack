import 'package:dev_stack/features/apps/data/app_installer_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppInstallerService.isPreferredCandidate', () {
    const root = '/opt/ponta/apps/flutter/3.47.9';

    test('prefers the SDK launcher over a copy nested deeper', () {
      // Flutter ships both: bin/dart is the launcher that bootstraps the SDK,
      // bin/cache/dart-sdk/bin/dart is the bundled binary it installs.
      expect(
        AppInstallerService.isPreferredCandidate(
          '$root/bin/dart',
          '$root/bin/cache/dart-sdk/bin/dart',
          root,
        ),
        isTrue,
      );
    });

    test('keeps the first match when depths are equal', () {
      expect(
        AppInstallerService.isPreferredCandidate(
          '$root/a/go',
          '$root/b/go',
          root,
        ),
        isFalse,
      );
    });

    test('does not replace a shallower match with a deeper one', () {
      expect(
        AppInstallerService.isPreferredCandidate(
          '$root/lib/bin/go',
          '$root/bin/go',
          root,
        ),
        isFalse,
      );
    });
  });
}
