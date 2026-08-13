import 'package:dev_stack/features/apps/data/app_installer_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppInstallerService.phpPortFor', () {
    test('maps php82 -> 9082, php85 -> 9085 (catalog convention)', () {
      expect(AppInstallerService.phpPortFor('php82'), 9082);
      expect(AppInstallerService.phpPortFor('php83'), 9083);
      expect(AppInstallerService.phpPortFor('php85'), 9085);
    });

    test('falls back to 9000 for non-conforming ids', () {
      // A single-digit id (php8) is not a MAJOR+MINOR id.
      expect(AppInstallerService.phpPortFor('php8'), 9000);
      // A dotted version is not supported by the catalog naming.
      expect(AppInstallerService.phpPortFor('php8.2'), 9000);
      // Something unrelated must never yield a guessed port.
      expect(AppInstallerService.phpPortFor('phpMyAdmin'), 9000);
      expect(AppInstallerService.phpPortFor('nginx'), 9000);
      expect(AppInstallerService.phpPortFor(''), 9000);
    });

    test('never produces a privileged or invalid port', () {
      // Hypothetical id that would yield <1024 must clamp to 9000.
      // 'php00' -> 9000 -> 000 < 1024 -> 9000.
      expect(AppInstallerService.phpPortFor('php00'), 9000);
      // 'php99' -> 9099, a valid unprivileged port.
      expect(AppInstallerService.phpPortFor('php99'), 9099);
    });
  });
}
