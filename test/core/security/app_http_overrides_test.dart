import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dev_stack/core/security/app_http_overrides.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late HttpOverrides? previousOverrides;

  setUp(() {
    previousOverrides = HttpOverrides.current;
  });

  tearDown(() {
    HttpOverrides.global = previousOverrides;
    AppHttpOverrides.setAllowInsecureSsl(false);
  });

  group('AppHttpOverrides.derToPem', () {
    test('wraps DER bytes in PEM headers with 64-char lines', () {
      // 100 bytes produces > 64 base64 characters, exercising line wrapping.
      final der = Uint8List.fromList(List<int>.generate(100, (i) => i & 0xff));
      final pem = AppHttpOverrides.derToPem(der);
      final lines = pem.trimRight().split('\n');

      expect(lines.first, '-----BEGIN CERTIFICATE-----');
      expect(lines.last, '-----END CERTIFICATE-----');

      final bodyLines = lines.sublist(1, lines.length - 1);
      expect(bodyLines.length, greaterThan(1));
      for (var i = 0; i < bodyLines.length - 1; i++) {
        expect(bodyLines[i].length, 64);
      }
      expect(bodyLines.last.length, inInclusiveRange(1, 64));

      final decoded = base64.decode(bodyLines.join());
      expect(decoded, equals(der));
    });
  });

  group('AppHttpOverrides.resolveLinuxCaBundlePaths', () {
    test('prioritizes SSL_CERT_FILE and appends default paths', () {
      final paths = AppHttpOverrides.resolveLinuxCaBundlePaths(
        environment: const {'SSL_CERT_FILE': '/custom/ca.pem'},
      );

      expect(paths.first, '/custom/ca.pem');
      expect(paths, contains('/etc/ssl/certs/ca-certificates.crt'));
      expect(paths, contains('/etc/pki/tls/certs/ca-bundle.crt'));
    });

    test('deduplicates SSL_CERT_FILE when it matches a default bundle', () {
      final paths = AppHttpOverrides.resolveLinuxCaBundlePaths(
        environment: const {
          'SSL_CERT_FILE': '/etc/ssl/certs/ca-certificates.crt',
        },
      );

      expect(
        paths.where((p) => p == '/etc/ssl/certs/ca-certificates.crt'),
        hasLength(1),
      );
      expect(paths.first, '/etc/ssl/certs/ca-certificates.crt');
    });

    test('returns default paths when SSL_CERT_FILE is unset or blank', () {
      final unsetPaths = AppHttpOverrides.resolveLinuxCaBundlePaths(
        environment: const {},
      );
      final blankPaths = AppHttpOverrides.resolveLinuxCaBundlePaths(
        environment: const {'SSL_CERT_FILE': '   '},
      );

      expect(unsetPaths, equals(blankPaths));
      expect(unsetPaths.first, '/etc/ssl/certs/ca-certificates.crt');
    });
  });

  group('AppHttpOverrides.loadPemCertificatesIntoContext', () {
    test('skips malformed PEM entries gracefully and returns 0', () {
      final context = SecurityContext();
      final loaded = AppHttpOverrides.loadPemCertificatesIntoContext(context, [
        'not a pem certificate',
        '-----BEGIN CERTIFICATE-----\nINVALID_BASE64\n-----END CERTIFICATE-----\n',
      ]);

      expect(loaded, 0);
    });

    test('returns 0 when certificate list is empty', () {
      final context = SecurityContext();
      expect(
        AppHttpOverrides.loadPemCertificatesIntoContext(context, const []),
        0,
      );
    });
  });

  group('AppHttpOverrides.install & allowInsecureSsl', () {
    test('installs global overrides and toggles allowInsecureSsl dynamically', () {
      AppHttpOverrides.install(allowInsecureSsl: false);

      expect(HttpOverrides.current, isA<AppHttpOverrides>());
      expect(AppHttpOverrides.allowInsecureSsl, isFalse);

      final client = HttpClient();
      addTearDown(() => client.close(force: true));
      expect(client, isNotNull);

      AppHttpOverrides.setAllowInsecureSsl(true);
      expect(AppHttpOverrides.allowInsecureSsl, isTrue);

      AppHttpOverrides.setAllowInsecureSsl(false);
      expect(AppHttpOverrides.allowInsecureSsl, isFalse);
    });
  });
}
