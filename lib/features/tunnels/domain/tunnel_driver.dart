import 'tunnel_model.dart';

abstract class TunnelDriver {
  String get providerId;

  List<String> buildStartArguments(TunnelModel tunnel, {String? defaultToken});

  /// Extracts the public URL from a log line. [customDomain] is the domain the
  /// user configured, used to pick the matching route when several are logged.
  String? parsePublicUrl(String logLine, {String? customDomain});

  /// Whether the log line proves the tunnel is serving traffic, even when it
  /// carries no public URL (e.g. Cloudflare token tunnels routed from the
  /// dashboard).
  bool isConnectionEstablished(String logLine);

  String? parseInspectorUrl(String logLine);
}

/// Turns a user-entered custom domain (`app.example.com`,
/// `https://app.example.com/`) into a URL, defaulting to https.
String? customDomainUrl(String? customDomain) {
  var domain = customDomain?.trim() ?? '';
  while (domain.endsWith('/')) {
    domain = domain.substring(0, domain.length - 1);
  }
  if (domain.isEmpty) return null;
  return domain.contains('://') ? domain : 'https://$domain';
}
