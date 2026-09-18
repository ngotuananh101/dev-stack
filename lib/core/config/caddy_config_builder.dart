import 'webserver_bind_policy.dart';

abstract final class CaddyConfigBuilder {
  static String _path(String value) => value.replaceAll('\\', '/');

  static String _fileLog(String path, {String indent = '        '}) =>
      '''${indent}output file "${_path(path)}" {
$indent    roll_size 10MiB
$indent    roll_keep 5
$indent    roll_keep_for 720h
$indent}''';

  /// Builds one site block. Caddy refuses an explicit `http://` address
  /// mixed with a `tls` directive, so HTTP and HTTPS addresses must be
  /// emitted as separate blocks.
  static String _siteBlock({
    required String address,
    required String bindAddress,
    required String body,
    String? tlsLine,
  }) =>
      '''$address {
    bind $bindAddress${tlsLine ?? ''}
$body
}
''';

  static String mainConfig({
    required String webRoot,
    required String bindAddress,
    required String vhostsGlob,
    required String integrationsGlob,
    required String localhostAccessLogPath,
    required String runtimeErrorLogPath,
    String? certPath,
    String? keyPath,
    int? phpPort,
  }) {
    if ((certPath == null) != (keyPath == null)) {
      throw ArgumentError('Certificate and key must be provided together');
    }
    final hasTls = certPath != null;
    final tlsLine = hasTls
        ? '\n    tls "${_path(certPath)}" "${_path(keyPath!)}"'
        : null;

    // PHP fastcgi handler so http(s)://localhost serves .php files
    String phpHandler = '';
    if (phpPort != null) {
      phpHandler = '\n    php_fastcgi 127.0.0.1:$phpPort';
    }

    final body =
        '''    root * "${_path(webRoot)}"
    file_server$phpHandler
    log {
${_fileLog(localhostAccessLogPath, indent: '        ')}
        format console
    }
    import "${_path(integrationsGlob)}"''';
    final blocks = [
      _siteBlock(
        address: WebserverBindPolicy.caddySiteAddress('localhost', ssl: false),
        bindAddress: bindAddress,
        body: body,
      ),
      if (hasTls)
        _siteBlock(
          address: WebserverBindPolicy.caddySiteAddress('localhost', ssl: true),
          bindAddress: bindAddress,
          body: body,
          tlsLine: tlsLine,
        ),
    ].join('\n');

    return '''{
    auto_https off
    log {
${_fileLog(runtimeErrorLogPath, indent: '        ')}
        format console
        level ERROR
        exclude http.log.access
    }
}

$blocks
import "${_path(vhostsGlob)}"
''';
  }

  static String siteConfig({
    required String domain,
    required String bindAddress,
    required String rootDir,
    required String siteType,
    required bool useSsl,
    required String accessLogPath,
    int? phpPort,
    String? proxyTarget,
    int? cliPort,
    String? certPath,
    String? keyPath,
  }) {
    if (!const {'static', 'php', 'proxy', 'cli'}.contains(siteType)) {
      throw ArgumentError('Unsupported site type: $siteType');
    }
    if (siteType == 'php' && (phpPort == null || phpPort <= 0)) {
      throw ArgumentError('PHP sites require a valid FastCGI port');
    }
    if (siteType == 'proxy' && (proxyTarget == null || proxyTarget.isEmpty)) {
      throw ArgumentError('Proxy sites require a target');
    }
    if (siteType == 'cli' && (cliPort == null || cliPort <= 0)) {
      throw ArgumentError('CLI sites require a valid port');
    }
    if (useSsl && (certPath == null || keyPath == null)) {
      throw ArgumentError('SSL sites require a certificate and key');
    }

    final handlers = switch (siteType) {
      'proxy' => '    reverse_proxy $proxyTarget',
      'cli' => '    reverse_proxy 127.0.0.1:$cliPort',
      'php' =>
        '''    root * "${_path(rootDir)}"
    php_fastcgi 127.0.0.1:$phpPort
    file_server''',
      _ =>
        '''    root * "${_path(rootDir)}"
    file_server''',
    };
    final body =
        '''$handlers
    log {
${_fileLog(accessLogPath, indent: '        ')}
        format console
    }''';
    final tlsLine = useSsl
        ? '\n    tls "${_path(certPath!)}" "${_path(keyPath!)}"'
        : null;

    return [
      _siteBlock(
        address: WebserverBindPolicy.caddySiteAddress(domain, ssl: false),
        bindAddress: bindAddress,
        body: body,
      ),
      if (useSsl)
        _siteBlock(
          address: WebserverBindPolicy.caddySiteAddress(domain, ssl: true),
          bindAddress: bindAddress,
          body: body,
          tlsLine: tlsLine,
        ),
    ].join('\n');
  }

  static String phpMyAdminIntegration({
    required String rootDir,
    required int phpPort,
  }) =>
      '''handle_path /phpmyadmin* {
    root * "${_path(rootDir)}"
    php_fastcgi 127.0.0.1:$phpPort
    file_server
}
''';
}
