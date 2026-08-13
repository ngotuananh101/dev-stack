import 'package:dev_stack/features/apps/data/app_service_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppServiceManager.parseListeningSockets', () {
    test('parses TCP LISTENING lines into host:port pairs', () {
      // Sample `netstat -ano` output (Windows).
      const output = '''
Active Connections

  Proto  Local Address          Foreign Address        State
  TCP    127.0.0.1:9082         0.0.0.0:0              LISTENING       4836
  TCP    0.0.0.0:80             0.0.0.0:0              LISTENING       1234
  TCP    [::]:9000              [::]:0                 LISTENING       5555
  TCP    192.168.1.5:3306       0.0.0.0:0              ESTABLISHED     9
''';
      final sockets = AppServiceManager.parseListeningSockets(output);
      expect(sockets, contains('127.0.0.1:9082'));
      expect(sockets, contains('0.0.0.0:80'));
      expect(sockets, contains('[::]:9000'));
      // ESTABLISHED rows must not be treated as listeners.
      expect(sockets, isNot(contains('192.168.1.5:3306')));
    });

    test('ignores malformed lines without throwing', () {
      const output = 'garbage\n\nTCP  nope  LISTENING 1';
      expect(AppServiceManager.parseListeningSockets(output), isEmpty);
    });
  });

  group('AppServiceManager.portIsHeld', () {
    test(
      '127.0.0.1:9082 held when that exact socket or 0.0.0.0 is listening',
      () {
        const output = 'TCP  127.0.0.1:9082  0.0.0.0:0  LISTENING  1';
        expect(
          AppServiceManager.portIsHeld(
            host: '127.0.0.1',
            port: 9082,
            listeningSockets: AppServiceManager.parseListeningSockets(output),
          ),
          isTrue,
        );
      },
    );

    test(
      '127.0.0.1:9082 held when 0.0.0.0:9082 is listening (wildcard bind)',
      () {
        const output = 'TCP  0.0.0.0:9082  0.0.0.0:0  LISTENING  1';
        expect(
          AppServiceManager.portIsHeld(
            host: '127.0.0.1',
            port: 9082,
            listeningSockets: AppServiceManager.parseListeningSockets(output),
          ),
          isTrue,
        );
      },
    );

    test('free when no matching listener', () {
      const output = 'TCP  127.0.0.1:9999  0.0.0.0:0  LISTENING  1';
      expect(
        AppServiceManager.portIsHeld(
          host: '127.0.0.1',
          port: 9082,
          listeningSockets: AppServiceManager.parseListeningSockets(output),
        ),
        isFalse,
      );
    });
  });

  group('AppServiceManager.parseHostPort', () {
    test('parses IPv4 host:port', () {
      final r = AppServiceManager.parseHostPort('127.0.0.1:9000');
      expect(r, isNotNull);
      expect(r!.host, '127.0.0.1');
      expect(r.port, 9000);
    });

    test('strips IPv6 brackets', () {
      final r = AppServiceManager.parseHostPort('[::]:9001');
      expect(r, isNotNull);
      expect(r!.host, '::');
      expect(r.port, 9001);
    });

    test('rejects malformed addresses', () {
      expect(AppServiceManager.parseHostPort('nope'), isNull);
      expect(AppServiceManager.parseHostPort(':9000'), isNull);
      expect(AppServiceManager.parseHostPort('host:'), isNull);
      expect(AppServiceManager.parseHostPort('host:99999'), isNull);
    });
  });
}
