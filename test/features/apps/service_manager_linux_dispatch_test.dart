import 'package:flutter_test/flutter_test.dart';
import 'package:dev_stack/features/apps/data/app_service_manager.dart';

void main() {
  group('normalizeExecutableName', () {
    test('strips windows extensions and lowercases', () {
      expect(AppServiceManager.normalizeExecutableName('CADDY.EXE'), 'caddy');
      expect(
        AppServiceManager.normalizeExecutableName('elasticsearch.bat'),
        'elasticsearch',
      );
      expect(
        AppServiceManager.normalizeExecutableName('redis-server'),
        'redis-server',
      );
      expect(
        AppServiceManager.normalizeExecutableName('php-cgi.exe'),
        'php-cgi',
      );
    });
  });

  group('linux dispatch tables accept ELF names', () {
    test('webservers run detached without extension', () {
      expect(AppServiceManager.runsDetachedExecutable('caddy'), isTrue);
      expect(AppServiceManager.runsDetachedExecutable('nginx'), isTrue);
      expect(AppServiceManager.runsDetachedExecutable('redis-server'), isFalse);
    });

    test('caddy gets run args and socket requirements', () {
      final sockets = AppServiceManager.requiredSocketsForExecutable('caddy');
      expect(sockets, hasLength(2));
      final args = AppServiceManager.argumentsForExecutable(
        'caddy',
        '/opt/caddy',
      );
      expect(args, containsAll(['run', '--adapter', 'caddyfile']));
    });
  });

  group('parseListeningSocketsLinux', () {
    test('collects LISTEN rows and expands wildcard stars', () {
      const ss =
          'State  Recv-Q Send-Q Local Address:Port Peer Address:Port\n'
          'LISTEN 0      128        127.0.0.1:9082      0.0.0.0:*   \n'
          'LISTEN 0      511            *:80               *:*     \n'
          'LISTEN 0      4096       [::]:443            [::]:*     \n'
          'ESTAB  0      0        10.0.0.2:22         10.0.0.1:5000\n';
      final sockets = AppServiceManager.parseListeningSocketsLinux(ss);
      expect(sockets.contains('127.0.0.1:9082'), isTrue);
      expect(sockets.contains('0.0.0.0:80'), isTrue);
      expect(
        sockets.contains('[::]:80'),
        isTrue,
      ); // '*' expands to both wildcards
      expect(sockets.contains('[::]:443'), isTrue);
      expect(sockets.any((s) => s.contains(':22')), isFalse);
    });
  });
}
