import 'package:flutter_test/flutter_test.dart';
import 'package:dev_stack/features/apps/data/apps_repository.dart';

void main() {
  group('AppsRepository - Catalog HTTPS Enforcement (VULN-12)', () {
    test('rejects HTTP url with ArgumentError', () async {
      final repo = AppsRepository();

      expect(
        () => repo.updateAppListFromUrl('http://example.com/apps.json'),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('HTTPS'),
        )),
      );
    });

    test('rejects FTP url with ArgumentError', () async {
      final repo = AppsRepository();

      expect(
        () => repo.updateAppListFromUrl('ftp://example.com/apps.json'),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('HTTPS'),
        )),
      );
    });

    test('rejects file scheme url with ArgumentError', () async {
      final repo = AppsRepository();

      expect(
        () => repo.updateAppListFromUrl('file:///etc/passwd'),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('HTTPS'),
        )),
      );
    });

    test('rejects invalid malformed url', () async {
      final repo = AppsRepository();

      expect(
        () => repo.updateAppListFromUrl('not a valid url'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('isSecureCatalogUrl accepts https and rejects others', () {
      expect(AppsRepository.isSecureCatalogUrl('https://example.com/apps.json'), isTrue);
      expect(AppsRepository.isSecureCatalogUrl('HTTPS://example.com/apps.json'), isTrue);
      expect(AppsRepository.isSecureCatalogUrl('http://example.com/apps.json'), isFalse);
      expect(AppsRepository.isSecureCatalogUrl('ftp://example.com/apps.json'), isFalse);
      expect(AppsRepository.isSecureCatalogUrl(''), isFalse);
      expect(AppsRepository.isSecureCatalogUrl('random string'), isFalse);
    });
  });
}
