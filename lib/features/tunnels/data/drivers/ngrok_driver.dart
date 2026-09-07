import 'dart:convert';
import '../../domain/tunnel_driver.dart';
import '../../domain/tunnel_model.dart';

class NgrokDriver implements TunnelDriver {
  @override
  String get providerId => 'ngrok';

  static final RegExp _fallbackUrlRegex = RegExp(r'https:\/\/[a-zA-Z0-9-]+\.(ngrok-free\.app|ngrok\.io|ngrok\.app)');
  static final RegExp _inspectorAddrRegex = RegExp(r'127\.0\.0\.1:\d+');

  @override
  List<String> buildStartArguments(
    TunnelModel tunnel, {
    String? defaultToken,
  }) {
    final args = <String>[
      'http',
      tunnel.targetPort.toString(),
      '--log=stdout',
      '--log-format=json',
    ];

    final token = tunnel.authToken ?? defaultToken;
    if (token != null && token.trim().isNotEmpty) {
      args.add('--authtoken');
      args.add(token.trim());
    }

    if (tunnel.customDomain != null && tunnel.customDomain!.trim().isNotEmpty) {
      args.add('--domain=${tunnel.customDomain!.trim()}');
    }

    return args;
  }

  @override
  String? parsePublicUrl(String logLine) {
    try {
      if (logLine.trim().startsWith('{') && logLine.trim().endsWith('}')) {
        final data = jsonDecode(logLine) as Map<String, dynamic>;
        if (data.containsKey('url') && data['url'] is String) {
          final url = data['url'] as String;
          if (url.startsWith('https://')) return url;
        }
      }
    } catch (_) {
      // Not JSON or parse error, fallback to regex
    }

    final match = _fallbackUrlRegex.firstMatch(logLine);
    return match?.group(0);
  }

  @override
  String? parseInspectorUrl(String logLine) {
    try {
      if (logLine.trim().startsWith('{') && logLine.trim().endsWith('}')) {
        final data = jsonDecode(logLine) as Map<String, dynamic>;
        if (data['msg'] == 'starting web service' && data['addr'] != null) {
          return 'http://${data['addr']}';
        }
      }
    } catch (_) {}

    if (logLine.contains('web service') || logLine.contains('127.0.0.1:4040')) {
      final match = _inspectorAddrRegex.firstMatch(logLine);
      if (match != null) {
        return 'http://${match.group(0)}';
      }
    }
    return null;
  }
}
