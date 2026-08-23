// test/features/apps/installer_linux_zonky_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dev_stack/features/apps/data/app_installer_service.dart';

void main() {
  group('Zonky PostgreSQL jar detection', () {
    test('recognizes embedded-postgres-binaries jars', () {
      expect(
        AppInstallerService.isZonkyPgJar(
          'https://repo1.maven.org/maven2/io/zonky/test/postgres/'
          'embedded-postgres-binaries-linux-amd64/17.2.0/'
          'embedded-postgres-binaries-linux-amd64-17.2.0.jar',
        ),
        isTrue,
      );
    });

    test('rejects unrelated jars, zips and tarballs', () {
      expect(AppInstallerService.isZonkyPgJar('https://example.com/app.jar'),
          isFalse);
      expect(AppInstallerService.isZonkyPgJar('https://example.com/x.zip'),
          isFalse);
      expect(AppInstallerService.isZonkyPgJar('https://example.com/x.tar.gz'),
          isFalse);
    });
  });
}
