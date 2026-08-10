import 'package:dev_stack/core/config/webserver_bind_policy.dart';
import 'package:dev_stack/features/settings/domain/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('LAN access is disabled by default', () {
    expect(AppSettings().allowLanAccess, isFalse);
  });

  group('WebserverBindPolicy', () {
    test('binds to localhost by default', () {
      expect(WebserverBindPolicy.address(allowLanAccess: false), '127.0.0.1');
      expect(
        WebserverBindPolicy.nginxListen(80, allowLanAccess: false),
        '127.0.0.1:80',
      );
      expect(
        WebserverBindPolicy.apacheVirtualHost(80, allowLanAccess: false),
        '127.0.0.1:80',
      );
    });

    test('binds to every interface only when LAN access is enabled', () {
      expect(WebserverBindPolicy.address(allowLanAccess: true), '0.0.0.0');
      expect(
        WebserverBindPolicy.nginxListen(80, allowLanAccess: true),
        '0.0.0.0:80',
      );
      expect(
        WebserverBindPolicy.apacheVirtualHost(443, allowLanAccess: true),
        '0.0.0.0:443',
      );
    });

    test('normalizes legacy Apache wildcard listeners to localhost', () {
      const legacy = '''
Listen 80
Listen 443
ServerName localhost:80
''';

      expect(
        WebserverBindPolicy.normalizeApacheListeners(
          legacy,
          allowLanAccess: false,
          includeSsl: true,
        ),
        contains('Listen 127.0.0.1:80\nListen 127.0.0.1:443'),
      );
    });

    test('removes stale duplicate listeners when LAN access is enabled', () {
      const mixed = '''
Listen 80
Listen 127.0.0.1:80
Listen 443
Listen 127.0.0.1:443
''';

      final normalized = WebserverBindPolicy.normalizeApacheListeners(
        mixed,
        allowLanAccess: true,
        includeSsl: true,
      );

      expect(
        RegExp(r'^Listen ', multiLine: true).allMatches(normalized),
        hasLength(2),
      );
      expect(normalized, contains('Listen 0.0.0.0:80'));
      expect(normalized, contains('Listen 0.0.0.0:443'));
    });

    test('preserves unrelated custom Apache listeners', () {
      const content = '''
Listen 80
Listen 8080
Listen 192.168.1.10:9000
''';

      final normalized = WebserverBindPolicy.normalizeApacheListeners(
        content,
        allowLanAccess: false,
        includeSsl: false,
      );

      expect(normalized, contains('Listen 127.0.0.1:80'));
      expect(normalized, contains('Listen 8080'));
      expect(normalized, contains('Listen 192.168.1.10:9000'));
    });

    test('adds the nginx SSL parameter without changing the address', () {
      expect(
        WebserverBindPolicy.nginxListen(443, allowLanAccess: false, ssl: true),
        '127.0.0.1:443 ssl',
      );
      expect(
        WebserverBindPolicy.nginxListen(443, allowLanAccess: true, ssl: true),
        '0.0.0.0:443 ssl',
      );
    });
  });
}
