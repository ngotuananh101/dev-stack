import 'package:dev_stack/features/sites/data/sites_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SitesNotifier.validateProxyTarget', () {
    test('accepts plain http(s) URLs', () {
      expect(
        SitesNotifier.validateProxyTarget('http://localhost:3000'),
        'http://localhost:3000',
      );
      expect(
        SitesNotifier.validateProxyTarget('https://api.example.com'),
        'https://api.example.com',
      );
      expect(
        SitesNotifier.validateProxyTarget('http://127.0.0.1:8080'),
        'http://127.0.0.1:8080',
      );
    });

    test('rejects non-http schemes', () {
      expect(
        () => SitesNotifier.validateProxyTarget('file:///etc/passwd'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => SitesNotifier.validateProxyTarget('javascript:alert(1)'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects newlines and semicolons that break nginx directives', () {
      expect(
        () => SitesNotifier.validateProxyTarget(
          'http://evil.com/;\n} location /secret {',
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => SitesNotifier.validateProxyTarget('http://evil.com/;bad'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => SitesNotifier.validateProxyTarget('http://evil.com\nbad'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects empty or schemeless values', () {
      expect(
        () => SitesNotifier.validateProxyTarget(''),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => SitesNotifier.validateProxyTarget('localhost:3000'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects values with curly braces that could close a block', () {
      expect(
        () => SitesNotifier.validateProxyTarget('http://evil.com/}'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => SitesNotifier.validateProxyTarget('http://evil.com/{'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
