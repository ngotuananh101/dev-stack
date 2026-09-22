import 'package:flutter_test/flutter_test.dart';
import 'package:dev_stack/features/tunnels/domain/tunnel_model.dart';
import 'package:dev_stack/features/tunnels/data/drivers/cloudflare_driver.dart';

void main() {
  final driver = CloudflareDriver();

  group('CloudflareDriver', () {
    test('builds arguments for quick tunnel without token', () {
      final tunnel = TunnelModel(
        name: 'Quick Tunnel',
        targetPort: 8080,
      );

      final args = driver.buildStartArguments(tunnel);
      expect(args, equals([
        'tunnel',
        '--url',
        'http://127.0.0.1:8080',
        '--no-tls-verify',
      ]));
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
      expect(args, equals([
        'tunnel',
        '--url',
        'http://127.0.0.1:80',
        '--no-tls-verify',
        '--http-host-header=myproject.test',
      ]));
    });

    test('builds arguments for named tunnel with token', () {
      final tunnel = TunnelModel(
        name: 'Named Tunnel',
        targetPort: 80,
        authToken: 'cf_token_12345',
      );

      final args = driver.buildStartArguments(tunnel);
      expect(args, equals([
        'tunnel',
        'run',
        '--token',
        'cf_token_12345',
      ]));
    });

    test('parses public URL from cloudflared log line', () {
      const logLine = '2026-09-07T05:22:00Z INF +--------------------------------------------------------------------------------------------+';
      const urlLine = '2026-09-07T05:22:00Z INF |  Your quick Tunnel has been created! Visit it at (it may take some time to be reachable):  |';
      const actualLine = '2026-09-07T05:22:00Z INF |  https://purple-butterfly-xyz.trycloudflare.com                                          |';

      expect(driver.parsePublicUrl(logLine), isNull);
      expect(driver.parsePublicUrl(urlLine), isNull);
      expect(
        driver.parsePublicUrl(actualLine),
        equals('https://purple-butterfly-xyz.trycloudflare.com'),
      );
    });
  });
}
