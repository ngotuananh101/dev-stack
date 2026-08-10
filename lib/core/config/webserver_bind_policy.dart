/// Shared bind-address policy for generated webserver configurations.
abstract final class WebserverBindPolicy {
  static String address({required bool allowLanAccess}) =>
      allowLanAccess ? '0.0.0.0' : '127.0.0.1';

  static String nginxListen(
    int port, {
    required bool allowLanAccess,
    bool ssl = false,
  }) => '${address(allowLanAccess: allowLanAccess)}:$port${ssl ? ' ssl' : ''}';

  static String apacheVirtualHost(int port, {required bool allowLanAccess}) =>
      '${address(allowLanAccess: allowLanAccess)}:$port';

  /// Replaces every legacy/wildcard Apache Listen directive with exactly one
  /// policy-compliant HTTP listener and, when requested, one HTTPS listener.
  static String normalizeApacheListeners(
    String content, {
    required bool allowLanAccess,
    required bool includeSsl,
  }) {
    final managedListener = RegExp(
      r'^\s*Listen\s+(?:[^\s:]+:)?(?:80|443)\s*$',
      caseSensitive: false,
    );
    final filtered = content
        .split('\n')
        .where((line) => !managedListener.hasMatch(line))
        .join('\n');
    final bindAddress = address(allowLanAccess: allowLanAccess);
    final listeners = [
      'Listen $bindAddress:80',
      if (includeSsl) 'Listen $bindAddress:443',
    ].join('\n');
    return '$listeners\n$filtered';
  }
}
