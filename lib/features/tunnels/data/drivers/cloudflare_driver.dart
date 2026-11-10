import 'dart:convert';

import '../../domain/tunnel_driver.dart';
import '../../domain/tunnel_model.dart';

class CloudflareDriver implements TunnelDriver {
  @override
  String get providerId => 'cloudflare';

  // api.trycloudflare.com is the endpoint cloudflared requests a quick tunnel
  // from (it shows up in error logs), not a tunnel URL.
  static final RegExp _urlRegex = RegExp(
    r'https:\/\/(?!api\.)[a-zA-Z0-9-]+\.trycloudflare\.com',
  );

  // Current cloudflared logs "Registered tunnel connection connIndex=0 ...",
  // older releases "Connection <uuid> registered".
  static final RegExp _registeredRegex = RegExp(
    r'Registered tunnel connection|Connection [0-9a-f-]+ registered',
  );

  // Remotely-managed (token) tunnels log their dashboard ingress rules as a
  // quoted JSON string: config="{\"ingress\":[...]}".
  static final RegExp _quotedConfigRegex = RegExp(
    r'config=("(?:[^"\\]|\\.)*")',
  );

  @override
  List<String> buildStartArguments(TunnelModel tunnel, {String? defaultToken}) {
    final token = tunnel.authToken ?? defaultToken;

    if (token != null && token.trim().isNotEmpty) {
      // Named/token tunnels read their origin (and Host header) from the
      // Cloudflare dashboard ingress config; the local --http-host-header flag
      // only applies to quick (--url) tunnels. Site routing for token tunnels
      // must therefore be configured there (httpHostHeader).
      return ['tunnel', 'run', '--token', token.trim()];
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
  String? parsePublicUrl(String logLine, {String? customDomain}) {
    final match = _urlRegex.firstMatch(logLine);
    if (match != null) return match.group(0);

    if (!logLine.contains('Updated to new configuration')) return null;
    return _pickIngressUrl(_ingressHostnames(logLine), customDomain);
  }

  @override
  bool isConnectionEstablished(String logLine) =>
      _registeredRegex.hasMatch(logLine);

  List<String> _ingressHostnames(String logLine) {
    final quoted = _quotedConfigRegex.firstMatch(logLine)?.group(1);
    if (quoted == null) return const [];
    try {
      final config = jsonDecode(jsonDecode(quoted) as String);
      final ingress = config is Map ? config['ingress'] : null;
      if (ingress is! List) return const [];
      return [
        for (final rule in ingress)
          if (rule is Map && rule['hostname'] is String)
            (rule['hostname'] as String).toLowerCase(),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Prefers the route serving [customDomain] (directly or via a wildcard),
  /// otherwise the first concrete hostname. A wildcard is never a URL by itself.
  String? _pickIngressUrl(List<String> hostnames, String? customDomain) {
    final url = customDomainUrl(customDomain);
    final host = url == null ? null : Uri.tryParse(url)?.host;
    if (host != null && host.isNotEmpty) {
      for (final hostname in hostnames) {
        final matches = hostname.startsWith('*.')
            ? host.endsWith(hostname.substring(1))
            : hostname == host;
        if (matches) return 'https://$host';
      }
    }

    for (final hostname in hostnames) {
      if (!hostname.contains('*')) return 'https://$hostname';
    }
    return null;
  }

  @override
  String? parseInspectorUrl(String logLine) => null;
}
