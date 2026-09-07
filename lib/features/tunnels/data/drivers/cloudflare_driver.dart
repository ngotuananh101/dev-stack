import '../../domain/tunnel_driver.dart';
import '../../domain/tunnel_model.dart';

class CloudflareDriver implements TunnelDriver {
  @override
  String get providerId => 'cloudflare';

  static final RegExp _urlRegex = RegExp(r'https:\/\/[a-zA-Z0-9-]+\.trycloudflare\.com');

  @override
  List<String> buildStartArguments(
    TunnelModel tunnel, {
    String? defaultToken,
  }) {
    final token = tunnel.authToken ?? defaultToken;

    if (token != null && token.trim().isNotEmpty) {
      return [
        'tunnel',
        'run',
        '--token',
        token.trim(),
      ];
    }

    return [
      'tunnel',
      '--url',
      'http://127.0.0.1:${tunnel.targetPort}',
      '--no-tls-verify',
    ];
  }

  @override
  String? parsePublicUrl(String logLine) {
    final match = _urlRegex.firstMatch(logLine);
    return match?.group(0);
  }

  @override
  String? parseInspectorUrl(String logLine) => null;
}
