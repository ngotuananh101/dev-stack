import 'webserver_bind_policy.dart';

abstract final class CaddyConfigBuilder {
  static String _path(String value) => value.replaceAll('\\', '/');

  static String _fileLog(String path, {String indent = '        '}) =>
      '''${indent}output file "${_path(path)}" {
$indent    roll_size 10MiB
$indent    roll_keep 5
$indent    roll_keep_for 720h
$indent}''';

  static String mainConfig({
    required String webRoot,
    required String bindAddress,
    required String vhostsGlob,
    required String integrationsGlob,
    required String localhostAccessLogPath,
    required String runtimeErrorLogPath,
    String? certPath,
    String? keyPath,
  }) {
    if ((certPath == null) != (keyPath == null)) {
      throw ArgumentError('Certificate and key must be provided together');
    }
    final hasTls = certPath != null;
    final addresses = [
      WebserverBindPolicy.caddySiteAddress('localhost', ssl: false),
      if (hasTls) WebserverBindPolicy.caddySiteAddress('localhost', ssl: true),
    ].join(', ');
    final tls = certPath != null
        ? '\n    tls "${_path(certPath)}" "${_path(keyPath!)}"'
        : '';

    return '''{
    auto_https off
    log {
${_fileLog(runtimeErrorLogPath, indent: '        ')}
        format console
        level ERROR
        exclude http.log.access
    }
}

$addresses {
    bind $bindAddress$tls
    root * "${_path(webRoot)}"
    file_server
    log {
${_fileLog(localhostAccessLogPath, indent: '        ')}
        format console
    }
    import "${_path(integrationsGlob)}"
}

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
    String? certPath,
    String? keyPath,
  }) {
    if (!const {'static', 'php', 'proxy'}.contains(siteType)) {
      throw ArgumentError('Unsupported site type: $siteType');
    }
    if (siteType == 'php' && (phpPort == null || phpPort <= 0)) {
      throw ArgumentError('PHP sites require a valid FastCGI port');
    }
    if (siteType == 'proxy' && (proxyTarget == null || proxyTarget.isEmpty)) {
      throw ArgumentError('Proxy sites require a target');
    }
    if (useSsl && (certPath == null || keyPath == null)) {
      throw ArgumentError('SSL sites require a certificate and key');
    }

    final addresses = [
      WebserverBindPolicy.caddySiteAddress(domain, ssl: false),
      if (useSsl) WebserverBindPolicy.caddySiteAddress(domain, ssl: true),
    ].join(', ');
    final tls = useSsl
        ? '\n    tls "${_path(certPath!)}" "${_path(keyPath!)}"'
        : '';

    final handlers = switch (siteType) {
      'proxy' => '    reverse_proxy $proxyTarget',
      'php' =>
        '''    root * "${_path(rootDir)}"
    php_fastcgi 127.0.0.1:$phpPort
    file_server''',
      _ =>
        '''    root * "${_path(rootDir)}"
    file_server''',
    };

    return '''$addresses {
    bind $bindAddress$tls
$handlers
    log {
${_fileLog(accessLogPath, indent: '        ')}
        format console
    }
}
''';
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
