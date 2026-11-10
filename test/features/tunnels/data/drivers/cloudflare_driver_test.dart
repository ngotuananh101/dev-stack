import 'package:flutter_test/flutter_test.dart';
import 'package:dev_stack/features/tunnels/domain/tunnel_model.dart';
import 'package:dev_stack/features/tunnels/data/drivers/cloudflare_driver.dart';

void main() {
  final driver = CloudflareDriver();

  group('CloudflareDriver', () {
    test('builds arguments for quick tunnel without token', () {
      final tunnel = TunnelModel(name: 'Quick Tunnel', targetPort: 8080);

      final args = driver.buildStartArguments(tunnel);
      expect(
        args,
        equals(['tunnel', '--url', 'http://127.0.0.1:8080', '--no-tls-verify']),
      );
    });

    test('site tunnel targets port 80 with the site Host header', () {
      final tunnel = TunnelModel(
        name: 'Site Tunnel',
        targetType: 'site',
        targetSiteDomain: 'myproject.test',
        // A stale cached FastCGI port must be ignored for site targets.
        targetPort: 9082,
      );

      final args = driver.buildStartArguments(tunnel);
      expect(
        args,
        equals([
          'tunnel',
          '--url',
          'http://127.0.0.1:80',
          '--no-tls-verify',
          '--http-host-header=myproject.test',
        ]),
      );
    });

    test('builds arguments for named tunnel with token', () {
      final tunnel = TunnelModel(
        name: 'Named Tunnel',
        targetPort: 80,
        authToken: 'cf_token_12345',
      );

      final args = driver.buildStartArguments(tunnel);
      expect(args, equals(['tunnel', 'run', '--token', 'cf_token_12345']));
    });

    test('parses public URL from cloudflared log line', () {
      const logLine =
          '2026-09-07T05:22:00Z INF +--------------------------------------------------------------------------------------------+';
      const urlLine =
          '2026-09-07T05:22:00Z INF |  Your quick Tunnel has been created! Visit it at (it may take some time to be reachable):  |';
      const actualLine =
          '2026-09-07T05:22:00Z INF |  https://purple-butterfly-xyz.trycloudflare.com                                          |';

      expect(driver.parsePublicUrl(logLine), isNull);
      expect(driver.parsePublicUrl(urlLine), isNull);
      expect(
        driver.parsePublicUrl(actualLine),
        equals('https://purple-butterfly-xyz.trycloudflare.com'),
      );
    });

    test('does not mistake the quick tunnel API endpoint for a public URL', () {
      const failureLine =
          '2026-11-06T02:10:11Z ERR Error unmarshaling QuickTunnel response: '
          'failed to request quick Tunnel: Post "https://api.trycloudflare.com/tunnel": dial tcp: i/o timeout';

      expect(driver.parsePublicUrl(failureLine), isNull);
    });

    group('token tunnels', () {
      const registeredLine =
          '2026-11-06T02:10:11Z INF Registered tunnel connection connIndex=0 '
          'connection=8f1c6a1e-2b7d-4e0a-9a51-3d0c2f6b7e44 event=0 ip=198.41.192.7 location=sin12 protocol=quic';
      const legacyRegisteredLine =
          '2026-11-06T02:10:11Z INF Connection 8f1c6a1e-2b7d-4e0a-9a51-3d0c2f6b7e44 '
          'registered connIndex=0 ip=198.41.192.7 location=SIN';
      const configLine =
          r'2026-11-06T02:10:11Z INF Updated to new configuration '
          r'config="{\"ingress\":[{\"hostname\":\"app.example.com\",\"originRequest\":{},\"service\":\"http://localhost:80\"},'
          r'{\"hostname\":\"api.example.com\",\"service\":\"http://localhost:3000\"},'
          r'{\"service\":\"http_status:404\"}],\"warp-routing\":{\"enabled\":false}}" version=3';
      const wildcardConfigLine =
          r'2026-11-06T02:10:11Z INF Updated to new configuration '
          r'config="{\"ingress\":[{\"hostname\":\"*.example.com\",\"service\":\"http://localhost:80\"},'
          r'{\"service\":\"http_status:404\"}]}" version=1';

      test(
        'reports an established connection once cloudflared registers one',
        () {
          expect(driver.isConnectionEstablished(registeredLine), isTrue);
          expect(driver.isConnectionEstablished(legacyRegisteredLine), isTrue);
          expect(
            driver.isConnectionEstablished(
              '2026-11-06T02:10:10Z INF Starting tunnel tunnelID=5d2b0a6e',
            ),
            isFalse,
          );
          expect(
            driver.isConnectionEstablished(
              '2026-11-06T02:10:10Z ERR Failed to dial a quic connection',
            ),
            isFalse,
          );
        },
      );

      test('takes the public URL from the dashboard ingress config', () {
        expect(
          driver.parsePublicUrl(configLine),
          equals('https://app.example.com'),
        );
      });

      test(
        'prefers the ingress hostname matching the configured custom domain',
        () {
          expect(
            driver.parsePublicUrl(configLine, customDomain: 'API.example.com'),
            equals('https://api.example.com'),
          );
          expect(
            driver.parsePublicUrl(
              wildcardConfigLine,
              customDomain: 'shop.example.com',
            ),
            equals('https://shop.example.com'),
          );
        },
      );

      test('never turns a wildcard ingress rule into a URL', () {
        expect(driver.parsePublicUrl(wildcardConfigLine), isNull);
      });
    });
  });
}
