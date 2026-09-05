import 'webserver_bind_policy.dart';

abstract final class NginxConfigBuilder {
  static String _path(String value) => value.replaceAll('\\', '/');

  /// Generates standard default mime.types content
  static String defaultMimeTypes() => '''types {
    text/html                             html htm shtml;
    text/css                              css;
    text/xml                              xml;
    image/gif                             gif;
    image/jpeg                            jpeg jpg;
    application/javascript                js;
    application/json                      json;
    image/png                             png;
    image/svg+xml                         svg svgz;
    image/x-icon                          ico;
    font/woff                             woff;
    font/woff2                            woff2;
}''';

  /// Generates the main `nginx.conf`
  static String buildMainConfig({
    required String webRoot,
    required String vhostsGlob,
    required String integrationsGlob,
    required bool allowLanAccess,
    required bool isSslInstalled,
    String? certPath,
    String? keyPath,
  }) {
    final cleanWebRoot = _path(webRoot);
    final cleanVhostsGlob = _path(vhostsGlob);
    final cleanIntegrationsGlob = _path(integrationsGlob);

    final httpListen = WebserverBindPolicy.nginxListen(
      80,
      allowLanAccess: allowLanAccess,
    );
    final httpsListen = WebserverBindPolicy.nginxListen(
      443,
      allowLanAccess: allowLanAccess,
      ssl: true,
    );

    String sslBlock = '';
    if (isSslInstalled && certPath != null && keyPath != null) {
      final cleanCert = _path(certPath);
      final cleanKey = _path(keyPath);
      sslBlock = '''
    # HTTPS server
    server {
        listen       $httpsListen;
        server_name  localhost;
        root         "$cleanWebRoot";

        ssl_certificate      "$cleanCert";
        ssl_certificate_key  "$cleanKey";

        ssl_session_cache    shared:SSL:1m;
        ssl_session_timeout  5m;

        ssl_ciphers  HIGH:!aNULL:!MD5;
        ssl_prefer_server_ciphers  on;

        location / {
            index  index.html index.htm index.php;
        }

        # Global Integrations
        include "$cleanIntegrationsGlob";
    }''';
    }

    return '''
worker_processes  auto;

events {
    worker_connections  1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;
    sendfile        on;
    keepalive_timeout  65;

    # HTTP server
    server {
        listen       $httpListen;
        server_name  localhost;
        root         "$cleanWebRoot";

        location / {
            index  index.html index.htm index.php;
        }

        # Global Integrations
        include "$cleanIntegrationsGlob";
    }

$sslBlock

    # Global Vhosts
    include "$cleanVhostsGlob";
}
''';
  }

  /// Builds a standard PHP location directive block
  static String buildPhpLocation({required int phpPort}) => '''
    location ~ \\.php\$ {
        fastcgi_pass 127.0.0.1:$phpPort;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_read_timeout 1800;
    }''';

  /// Builds phpMyAdmin integration configuration for Nginx
  static String buildPhpMyAdminConfig({
    required String rootDir,
    required dynamic phpPort, // int or String
  }) {
    final cleanRootDir = _path(rootDir);
    return '''
# phpMyAdmin Integration
location /phpmyadmin {
    alias "$cleanRootDir/";
    index index.php;
    try_files \$uri \$uri/ /index.php?\$args;

    location ~ ^/phpmyadmin/(.+\\.php)\$ {
        alias "$cleanRootDir/\$1";
        fastcgi_pass 127.0.0.1:$phpPort;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$request_filename;
    }
}
''';
  }

  /// Builds a site vhost configuration for Nginx
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

    String buildServerBlock(int port, {bool ssl = false}) {
      final listen = WebserverBindPolicy.nginxListen(
        port,
        allowLanAccess: allowLanAccess,
        ssl: ssl,
      );
      var config = 'server {\n';
      config += '    listen $listen;\n';
      config += '    server_name $domain;\n';
      config += '\n';
      config += '    client_max_body_size 512M;\n';
      config += '    send_timeout 1800;\n';
      config += '    proxy_read_timeout 1800;\n';

      if (siteType != 'proxy') {
        config += '    root "$rootDirUnix";\n';
        config += '    index index.php index.html;\n';
      }

      if (ssl && certPath != null && keyPath != null) {
        final certUnix = _path(certPath);
        final keyUnix = _path(keyPath);
        config += '\n';
        config += '    ssl_certificate      "$certUnix";\n';
        config += '    ssl_certificate_key  "$keyUnix";\n';
        config += '    ssl_session_cache    shared:SSL:1m;\n';
        config += '    ssl_session_timeout  5m;\n';
        config += '    ssl_ciphers  HIGH:!aNULL:!MD5;\n';
        config += '    ssl_prefer_server_ciphers  on;\n';
      }

      config += '\n';
      config += '    access_log "$accessLogUnix";\n';
      config += '    error_log "$errorLogUnix";\n';
      config += '\n';

      if (siteType == 'proxy') {
        config += '    location / {\n';
        config += '        proxy_pass $proxyTarget;\n';
        config += '        proxy_set_header Host \$host;\n';
        config += '        proxy_set_header X-Real-IP \$remote_addr;\n';
        config +=
            '        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;\n';
        config += '        proxy_set_header X-Forwarded-Proto \$scheme;\n';
        config += '    }\n';
      } else {
        config += '    location / {\n';
        config += '        try_files \$uri \$uri/ /index.php?\$query_string;\n';
        config += '    }\n';

        if (siteType == 'php') {
          config += '\n';
          config += '    location ~ \\.php\$ {\n';
          config += '        fastcgi_pass 127.0.0.1:$phpPort;\n';
          config += '        fastcgi_index index.php;\n';
          config += '        include fastcgi_params;\n';
          config +=
              '        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;\n';
          config += '        fastcgi_read_timeout 1800;\n';
          config += '    }\n';
        }
      }

      config += '}\n';
      return config;
    }

    String result = buildServerBlock(80);
    if (useSsl) {
      result += '\n${buildServerBlock(443, ssl: true)}';
    }
    return result;
  }
}
