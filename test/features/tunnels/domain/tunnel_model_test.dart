import 'package:flutter_test/flutter_test.dart';
import 'package:dev_stack/features/tunnels/domain/tunnel_model.dart';
import 'package:dev_stack/features/tunnels/domain/tunnel_session.dart';

void main() {
  group('TunnelModel', () {
    test('instantiates with default values', () {
      final tunnel = TunnelModel(
        name: 'My Shop',
        targetPort: 80,
      );

      expect(tunnel.name, equals('My Shop'));
      expect(tunnel.provider, equals('cloudflare'));
      expect(tunnel.targetType, equals('site'));
      expect(tunnel.targetPort, equals(80));
      expect(tunnel.autoStart, isFalse);
      expect(tunnel.authToken, isNull);
      expect(tunnel.customDomain, isNull);
    });

    test('supports custom provider and port config', () {
      final tunnel = TunnelModel(
        name: 'Custom API',
        provider: 'ngrok',
        targetType: 'port',
        targetPort: 3000,
        authToken: 'test_token',
        customDomain: 'api.devstack.me',
        autoStart: true,
      );

      expect(tunnel.provider, equals('ngrok'));
      expect(tunnel.targetType, equals('port'));
      expect(tunnel.targetPort, equals(3000));
      expect(tunnel.authToken, equals('test_token'));
      expect(tunnel.customDomain, equals('api.devstack.me'));
      expect(tunnel.autoStart, isTrue);
    });
  });

  group('TunnelSession', () {
    test('initializes with stopped status and handles copyWith', () {
      const session = TunnelSession(tunnelId: 1);
      expect(session.status, equals(TunnelStatus.stopped));
      expect(session.publicUrl, isNull);
      expect(session.downloadProgress, equals(0.0));

      final updated = session.copyWith(
        status: TunnelStatus.running,
        publicUrl: 'https://test.trycloudflare.com',
        pid: 1234,
      );

      expect(updated.status, equals(TunnelStatus.running));
      expect(updated.publicUrl, equals('https://test.trycloudflare.com'));
      expect(updated.pid, equals(1234));
      expect(updated.tunnelId, equals(1));
    });
  });
}
