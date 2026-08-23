import 'package:flutter_test/flutter_test.dart';
import 'package:dev_stack/features/apps/data/app_installer_service.dart';

void main() {
  group('composerGlobalBinDir', () {
    test('uses APPDATA vendor bin on Windows', () {
      final got = AppInstallerService.composerGlobalBinDir(
        isWindows: true,
        home: '/home/u',
        appData: r'C:\Users\u\AppData\Roaming',
      );
      expect(
        got,
        equals(r'C:\Users\u\AppData\Roaming' r'\Composer\vendor\bin'),
      );
    });

    test('uses XDG config path on Linux', () {
      expect(
        AppInstallerService.composerGlobalBinDir(
          isWindows: false,
          home: '/home/u',
        ),
        equals('/home/u/.config/composer/vendor/bin'),
      );
    });
  });
}
