import 'package:flutter_test/flutter_test.dart';
import 'package:dev_stack/features/tunnels/domain/tunnel_model.dart';
import 'package:dev_stack/features/tunnels/data/drivers/ngrok_driver.dart';

void main() {
  final driver = NgrokDriver();

  group('NgrokDriver', () {
    test('builds start arguments for port with token', () {
      final tunnel = TunnelModel(
        name: 'Ngrok Port',
        targetPort: 3000,
        authToken: 'token_abc',
      );

      final args = driver.buildStartArguments(tunnel);
      expect(args, contains('http'));
      expect(args, contains('3000'));
      expect(args, contains('--authtoken'));
      expect(args, contains('token_abc'));
      expect(args, contains('--log=stdout'));
      expect(args, contains('--log-format=json'));
    });

    test('builds start arguments with custom domain', () {
      final tunnel = TunnelModel(
        name: 'Custom Ngrok',
        targetPort: 80,
        customDomain: 'demo.devstack.io',
      );

      final args = driver.buildStartArguments(tunnel);
      expect(args, contains('--domain=demo.devstack.io'));
    });

    test('parses public URL from json log', () {
      const jsonLine = '{"lvl":"info","msg":"started tunnel","obj":"tunnels","name":"command_line","addr":"http://localhost:3000","url":"https://1234-5678.ngrok-free.app"}';
      final url = driver.parsePublicUrl(jsonLine);
      expect(url, equals('https://1234-5678.ngrok-free.app'));
    });

    test('extracts inspector URL', () {
      const inspectLine = '{"lvl":"info","msg":"starting web service","obj":"web","addr":"127.0.0.1:4040"}';
      final inspector = driver.parseInspectorUrl(inspectLine);
      expect(inspector, equals('http://127.0.0.1:4040'));
    });
  });
}
