import 'package:dev_stack/features/sites/data/sites_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Sites.validateProxyTarget', () {
    test('accepts plain http(s) URLs', () {
      expect(
        Sites.validateProxyTarget('http://localhost:3000'),
        'http://localhost:3000',
      );
      expect(
        Sites.validateProxyTarget('https://api.example.com'),
        'https://api.example.com',
      );
      expect(
        Sites.validateProxyTarget('http://127.0.0.1:8080'),
        'http://127.0.0.1:8080',
      );
    });

    test('rejects non-http schemes', () {
      expect(
        () => Sites.validateProxyTarget('file:///etc/passwd'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => Sites.validateProxyTarget('javascript:alert(1)'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
      'rejects characters that break nginx, Apache, or Caddy directives',
      () {
        expect(
          () => Sites.validateProxyTarget(
            'http://evil.com/;\n} location /secret {',
          ),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => Sites.validateProxyTarget('http://evil.com/;bad'),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => Sites.validateProxyTarget('http://evil.com\nbad'),
          throwsA(isA<ArgumentError>()),
        );
      },
    );

    test('rejects empty or schemeless values', () {
      expect(
        () => Sites.validateProxyTarget(''),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => Sites.validateProxyTarget('localhost:3000'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects values with curly braces that could close a block', () {
      expect(
        () => Sites.validateProxyTarget('http://evil.com/}'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => Sites.validateProxyTarget('http://evil.com/{'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
