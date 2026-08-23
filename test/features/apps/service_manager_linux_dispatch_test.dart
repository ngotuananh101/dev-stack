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
        AppServiceManager.normalizeExecutableName('valkey-server'),
        'valkey-server',
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

    test('nginx gets run args and socket requirements', () {
      final sockets = AppServiceManager.requiredSocketsForExecutable('nginx');
      expect(sockets, hasLength(2));
      final args = AppServiceManager.argumentsForExecutable(
        'nginx',
        '/opt/ponta/apps/nginx/1.30.4',
      );
      expect(args, containsAll(['-p', '/opt/ponta/apps/nginx/1.30.4/', '-c', '/opt/ponta/apps/nginx/1.30.4/conf/nginx.conf']));
    });
  });

  group('parseListeningSocketsLinux', () {
    test('collects LISTEN rows and expands wildcard stars (5-column format)', () {
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

    test('parses standard 7-column ss -tulpn output with tcp/udp prefix', () {
      const ss =
          'Netid State  Recv-Q Send-Q  Local Address:Port   Peer Address:Port Process\n'
          'tcp   LISTEN 0      128         127.0.0.1:9082        0.0.0.0:*     users:(("php-cgi",pid=123,fd=3))\n'
          'tcp   LISTEN 0      511           0.0.0.0:80          0.0.0.0:*     users:(("caddy",pid=456,fd=4))\n'
          'tcp   LISTEN 0      4096             [::]:443            [::]:*     users:(("caddy",pid=456,fd=5))\n'
          'udp   UNCONN 0      0             0.0.0.0:5353        0.0.0.0:*     users:(("avahi-daemon",pid=789,fd=6))\n'
          'tcp   ESTAB  0      0          10.0.0.2:22         10.0.0.1:5000  users:(("sshd",pid=101,fd=3))\n';
      final sockets = AppServiceManager.parseListeningSocketsLinux(ss);
      expect(sockets, contains('127.0.0.1:9082'));
      expect(sockets, contains('0.0.0.0:80'));
      expect(sockets, contains('[::]:443'));
      expect(sockets.contains('0.0.0.0:5353'), isFalse);
      expect(sockets.any((s) => s.contains(':22')), isFalse);
    });

    test('handles edge cases such as empty lines, malformed lines, and invalid ports', () {
      const ss =
          '\n'
          '   \n'
          'LISTEN\n'
          'LISTEN 0\n'
          'LISTEN 0 128\n'
          'tcp LISTEN 0 128 invalid-no-port 0.0.0.0:*\n'
          'tcp LISTEN 0 128 127.0.0.1:not_a_port 0.0.0.0:*\n'
          'tcp LISTEN 0 128 :8080 0.0.0.0:*\n'
          'tcp LISTEN 0 128 0.0.0.0:3306 0.0.0.0:*\n';
      final sockets = AppServiceManager.parseListeningSocketsLinux(ss);
      expect(sockets, equals({'0.0.0.0:3306'}));
    });
  });
}
