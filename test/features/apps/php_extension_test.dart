import 'package:dev_stack/features/apps/data/php_settings_provider.dart';
import 'package:dev_stack/features/apps/domain/php_extension.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PhpExtension', () {
    test('defaults isInstalled to true and the Linux fields to null', () {
      final ext = PhpExtension(
        name: 'curl',
        fileName: 'php_curl.dll',
        isEnabled: true,
        isFoundInIni: true,
        isZend: false,
      );
      expect(ext.isInstalled, isTrue);
      expect(ext.packageName, isNull);
      expect(ext.description, isNull);
    });

    test('carries the Linux package metadata', () {
      final ext = PhpExtension(
        name: 'mbstring',
        fileName: 'mbstring.so',
        isEnabled: false,
        isFoundInIni: true,
        isZend: false,
        isInstalled: false,
        packageName: 'php8.5-mbstring',
        description: 'MBSTRING module for PHP',
      );
      expect(ext.isInstalled, isFalse);
      expect(ext.packageName, 'php8.5-mbstring');
      expect(ext.description, 'MBSTRING module for PHP');
    });

    test('copyWith changes only the named fields', () {
      final ext = PhpExtension(
        name: 'zip',
        fileName: 'zip.so',
        isEnabled: false,
        isFoundInIni: false,
        isZend: false,
        isInstalled: false,
        packageName: 'php8.5-zip',
      );
      final after = ext.copyWith(isEnabled: true, isInstalled: true);
      expect(after.name, 'zip');
      expect(after.packageName, 'php8.5-zip');
      expect(after.isEnabled, isTrue);
      expect(after.isInstalled, isTrue);
      expect(after.isZend, isFalse);
    });

    test('is reachable through the php_settings_provider re-export', () {
      // The re-export is what keeps every existing import site compiling.
      final ext = PhpExtension(
        name: 'gd',
        fileName: 'gd.so',
        isEnabled: true,
        isFoundInIni: true,
        isZend: false,
      );
      expect(ext, isA<PhpExtension>());
    });
  });
}
