import 'package:flutter_test/flutter_test.dart';
import 'package:dev_stack/features/apps/data/app_service_manager.dart';

void main() {
  group('linux foreground service arguments', () {
    test('apache2 gets foreground and isolated httpd.conf', () {
      final args = AppServiceManager.argumentsForExecutable(
        'apache2',
        '/usr/sbin',
        isLinux: true,
      );
      expect(args, contains('-DFOREGROUND'));
      expect(args, contains('-f'));
      expect(args.last, contains('httpd.conf'));
    });

    test('httpd also gets foreground and isolated httpd.conf', () {
      final args = AppServiceManager.argumentsForExecutable(
        'httpd',
        '/usr/sbin',
        isLinux: true,
      );
      expect(args, contains('-DFOREGROUND'));
      expect(args, contains('-f'));
      expect(args.last, contains('httpd.conf'));
    });

    test('redis-server receives isolated redis.conf from ~/.ponta/data/redis', () {
      final args = AppServiceManager.argumentsForExecutable(
        'redis-server',
        '/usr/bin',
        isLinux: true,
      );
      expect(args, hasLength(1));
      expect(args.first, contains('redis.conf'));
    });

    test('php-fpm receives foreground -F and -y config flags', () {
      final args = AppServiceManager.argumentsForExecutable(
        'php-fpm8.2',
        '/usr/sbin',
        appId: 'php82',
        isLinux: true,
      );
      expect(args, containsAll(['-F', '-y']));
      expect(args.last, contains('php-fpm.conf'));
    });

    test('postgres receives -D with isolated data directory', () {
      final args = AppServiceManager.argumentsForExecutable(
        'postgres',
        '/usr/lib/postgresql/16/bin',
        appId: 'postgresql',
        installedVersion: '16',
        isLinux: true,
      );
      expect(args, contains('-D'));
      expect(args, hasLength(2));
      expect(args.last, contains('postgresql-16'));
    });
  });

  group('requiredSocketsForExecutable includes database and runtime ports', () {
    test('redis requires 6379', () {
      final sockets = AppServiceManager.requiredSocketsForExecutable('redis-server');
      expect(sockets.any((s) => s.port == 6379), isTrue);
    });

    test('postgres requires 5432', () {
      final sockets = AppServiceManager.requiredSocketsForExecutable('postgres');
      expect(sockets.any((s) => s.port == 5432), isTrue);
    });

    test('apache2 requires 80 and 443', () {
      final sockets = AppServiceManager.requiredSocketsForExecutable('apache2');
      expect(sockets.any((s) => s.port == 80), isTrue);
      expect(sockets.any((s) => s.port == 443), isTrue);
    });

    test('php-fpm8.2 requires 9082 when appId provided', () {
      final sockets = AppServiceManager.requiredSocketsForExecutable(
        'php-fpm8.2',
        appId: 'php82',
      );
      expect(sockets.any((s) => s.port == 9082), isTrue);
    });
  });

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
