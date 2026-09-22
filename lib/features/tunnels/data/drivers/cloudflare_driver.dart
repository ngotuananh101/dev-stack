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
      // Named/token tunnels read their origin (and Host header) from the
      // Cloudflare dashboard ingress config; the local --http-host-header flag
      // only applies to quick (--url) tunnels. Site routing for token tunnels
      // must therefore be configured there (httpHostHeader).
      return [
        'tunnel',
        'run',
        '--token',
        token.trim(),
      ];
    }

    // Site tunnels must hit the webserver's HTTP port (80) and carry the
    // site's domain as the Host header, otherwise nginx falls through to the
    // default vhost and serves the wrong site. Port-target tunnels keep their
    // configured port and no Host override. The cached phpPort stored on some
    // site tunnels is intentionally ignored for site targets.
    final siteDomain = tunnel.targetSiteDomain?.trim();
    final isSite = siteDomain != null && siteDomain.isNotEmpty;
    final port = isSite ? 80 : tunnel.targetPort;

    final args = [
      'tunnel',
      '--url',
      'http://127.0.0.1:$port',
      '--no-tls-verify',
    ];

    if (isSite) {
      args.add('--http-host-header=$siteDomain');
    }

    return args;
  }

  @override
  String? parsePublicUrl(String logLine) {
    final match = _urlRegex.firstMatch(logLine);
    return match?.group(0);
  }

  @override
  String? parseInspectorUrl(String logLine) => null;
}
