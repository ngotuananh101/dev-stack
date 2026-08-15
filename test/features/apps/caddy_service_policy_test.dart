import 'package:dev_stack/features/apps/data/app_service_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('Caddy service policy', () {
    test('runs Caddy in foreground mode under managed launcher', () {
      expect(AppServiceManager.runsDetachedExecutable('caddy.exe'), isTrue);
      expect(AppServiceManager.runsDetachedExecutable('CADDY.EXE'), isTrue);
    });

    test('passes explicit Caddyfile adapter arguments', () {
      final args = AppServiceManager.argumentsForExecutable(
        'caddy.exe',
        r'C:\Ponta\apps\caddy\2.11.4',
      );

      expect(args, [
        'run',
        '--config',
        p.join(r'C:\Ponta\apps\caddy\2.11.4', 'Caddyfile'),
        '--adapter',
        'caddyfile',
      ]);
    });

    test('preflights HTTP and HTTPS on every interface', () {
      expect(AppServiceManager.requiredSocketsForExecutable('caddy.exe'), [
        (host: '*', port: 80),
        (host: '*', port: 443),
      ]);
    });
  });
}
