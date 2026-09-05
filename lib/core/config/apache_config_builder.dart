import 'webserver_bind_policy.dart';

abstract final class ApacheConfigBuilder {
  static String _path(String value) => value.replaceAll('\\', '/');

  /// Transforms and configures the main Apache `httpd.conf` content.
  static String buildMainConfig({
    required String initialContent,
    required String serverRoot,
    required String documentRoot,
    required String vhostsGlob,
    required bool allowLanAccess,
    required bool isSslInstalled,
    String? certPath,
    String? keyPath,
  }) {
    var content = initialContent;
    final srvRoot = _path(serverRoot);
    final webRoot = _path(documentRoot);

    // 1. Fix SRVROOT (Essential for Apache Lounge binaries)
    content = content.replaceFirst(
      RegExp(r'Define\s+SRVROOT\s+".*?"'),
      'Define SRVROOT "$srvRoot"',
    );

    // 2. Replace DocumentRoot
    content = content.replaceFirst(
      RegExp(r'^DocumentRoot\s+.*$', multiLine: true),
      'DocumentRoot "$webRoot"',
    );

    // 3. Replace the corresponding <Directory> block
    content = content.replaceFirst(
      RegExp(r'^<Directory\s+"[^/].*?">', multiLine: true),
      '<Directory "$webRoot">',
    );

    // 4. Ensure permissions for the new root
    content = content.replaceFirst(
      '<Directory "$webRoot">',
      '<Directory "$webRoot">\n    Options Indexes FollowSymLinks\n    AllowOverride All\n    Require all granted',
    );

    // 5. Bind policy normalization
    content = WebserverBindPolicy.normalizeApacheListeners(
      content,
      allowLanAccess: allowLanAccess,
      includeSsl: isSslInstalled,
    );

    // 6. Fix ServerName warning
    if (!content.contains('ServerName localhost')) {
      content = content.replaceFirst(
        RegExp(r'^#?ServerName\s+.*$', multiLine: true),
        'ServerName localhost:80',
      );
    }

    // SSL Configuration for Apache
    const sslVhostMarker = '# Ponta SSL Virtual Host';
    if (isSslInstalled) {
      // Enable mod_ssl and socache_shmcb
      content = content.replaceFirst(
        RegExp(r'#\s*LoadModule\s+ssl_module\s+modules/mod_ssl.so'),
        'LoadModule ssl_module modules/mod_ssl.so',
      );
      content = content.replaceFirst(
        RegExp(
          r'#\s*LoadModule\s+socache_shmcb_module\s+modules/mod_socache_shmcb.so',
        ),
        'LoadModule socache_shmcb_module modules/mod_socache_shmcb.so',
      );

      // Enable proxy modules for PHP-CGI
      content = content.replaceFirst(
        RegExp(r'#\s*LoadModule\s+proxy_module\s+modules/mod_proxy.so'),
        'LoadModule proxy_module modules/mod_proxy.so',
      );
      content = content.replaceFirst(
        RegExp(
          r'#\s*LoadModule\s+proxy_fcgi_module\s+modules/mod_proxy_fcgi.so',
        ),
        'LoadModule proxy_fcgi_module modules/mod_proxy_fcgi.so',
      );

      final bindAddress = WebserverBindPolicy.address(
        allowLanAccess: allowLanAccess,
      );
      final cleanCert = certPath != null ? _path(certPath) : '';
      final cleanKey = keyPath != null ? _path(keyPath) : '';

      final sslVhost = '''
$sslVhostMarker
<IfModule mod_ssl.c>
<VirtualHost $bindAddress:443>
    DocumentRoot "$webRoot"
    ServerName localhost:443
    SSLEngine on
    SSLCertificateFile "$cleanCert"
    SSLCertificateKeyFile "$cleanKey"
    <Directory "$webRoot">
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
</IfModule>
''';
      final existingRegex = RegExp(
        r'\s*' + RegExp.escape(sslVhostMarker) + r'.*?<\/IfModule>',
        dotAll: true,
      );
      content = content.replaceAll(existingRegex, '');
      content += '\n$sslVhost\n';
    } else {
      if (content.contains(sslVhostMarker)) {
        final existingRegex = RegExp(
          r'\s*' + RegExp.escape(sslVhostMarker) + r'.*?<\/IfModule>',
          dotAll: true,
        );
        content = content.replaceAll(existingRegex, '');
      }
    }

    // Include global vhosts
    final vhostsPath = _path(vhostsGlob);
    if (!content.contains('IncludeOptional "$vhostsPath"')) {
      content += '\n# Global Vhosts\nIncludeOptional "$vhostsPath"\n';
    }

    return content;
  }

  /// Builds a FastCGI SetHandler block for PHP-FPM
  static String buildPhpFpmConfig({required int phpPort}) => '''
    <FilesMatch \\.php\$>
        SetHandler "proxy:fcgi://127.0.0.1:$phpPort"
    </FilesMatch>''';

  /// Builds phpMyAdmin VirtualHost or Directory configuration for Apache
  static String buildPhpMyAdminConfig(
    String pmaPathUnix, {
    int phpPort = 9000,
  }) {
    final cleanPmaPath = _path(pmaPathUnix);
    final trailingSlashPmaPath =
        cleanPmaPath.endsWith('/') ? cleanPmaPath : '$cleanPmaPath/';
    return '''
# phpMyAdmin Configuration
Alias /phpmyadmin "$trailingSlashPmaPath"
<Directory "$trailingSlashPmaPath">
    Options Indexes FollowSymLinks MultiViews
    AllowOverride All
    Require all granted
    <FilesMatch \\.php\$>
        SetHandler "proxy:fcgi://127.0.0.1:$phpPort"
    </FilesMatch>
</Directory>
''';
  }

  /// Builds site vhost configuration for Apache
  static String siteConfig({
    required String domain,
    required String rootDir,
    required String siteType,
    required bool useSsl,
    required String accessLogPath,
    required String errorLogPath,
    required bool allowLanAccess,
    int? phpPort,
    String? proxyTarget,
    String? certPath,
    String? keyPath,
  }) {
    final rootDirUnix = _path(rootDir);
    final accessLogUnix = _path(accessLogPath);
    final errorLogUnix = _path(errorLogPath);

    String buildVirtualHost(int port, {bool ssl = false}) {
      final virtualHost = WebserverBindPolicy.apacheVirtualHost(
        port,
        allowLanAccess: allowLanAccess,
      );
      var config = '<VirtualHost $virtualHost>\n';
      config += '    ServerName $domain\n';

      if (siteType != 'proxy') {
        config += '    DocumentRoot "$rootDirUnix"\n';
      }

      if (ssl && certPath != null && keyPath != null) {
        final certUnix = _path(certPath);
        final keyUnix = _path(keyPath);
        config += '    SSLEngine on\n';
        config += '    SSLCertificateFile "$certUnix"\n';
        config += '    SSLCertificateKeyFile "$keyUnix"\n';
      }

      config += '\n';
      config += '    CustomLog "$accessLogUnix" combined\n';
      config += '    ErrorLog "$errorLogUnix"\n';
      config += '\n';

      if (siteType == 'proxy') {
        final target = proxyTarget ?? '';
        final safeTarget = target.endsWith('/') ? target : '$target/';
        config += '    ProxyPreserveHost On\n';
        config += '    ProxyPass / $safeTarget\n';
        config += '    ProxyPassReverse / $safeTarget\n';
      } else {
        config += '    <Directory "$rootDirUnix">\n';
        config += '        Options Indexes FollowSymLinks\n';
        config += '        AllowOverride All\n';
        config += '        Require all granted\n';
        config += '    </Directory>\n';

        if (siteType == 'php') {
          config += '\n';
          config += '    <FilesMatch \\.php\$>\n';
          config += '        SetHandler "proxy:fcgi://127.0.0.1:$phpPort"\n';
          config += '    </FilesMatch>\n';
        }
      }

      config += '</VirtualHost>\n';
      return config;
    }

    var result = buildVirtualHost(80);
    if (useSsl) {
      result += '\n<IfModule mod_ssl.c>\n';
      result += buildVirtualHost(443, ssl: true);
      result += '</IfModule>\n';
    }
    return result;
  }
}
