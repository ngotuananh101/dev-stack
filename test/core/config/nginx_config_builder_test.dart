import 'package:dev_stack/core/config/nginx_config_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NginxConfigBuilder.buildMainConfig', () {
    test('builds HTTP server without SSL and normalizes paths', () {
      final config = NginxConfigBuilder.buildMainConfig(
        webRoot: r'C:\Ponta\www',
        vhostsGlob: r'C:\Ponta\vhosts\nginx\*.conf',
        integrationsGlob: r'C:\Ponta\vhosts\nginx\integrations\*.conf',
        allowLanAccess: false,
        isSslInstalled: false,
      );

      expect(config, contains('worker_processes  auto;'));
      expect(config, contains('listen       127.0.0.1:80;'));
      expect(config, contains('server_name  localhost;'));
      expect(config, contains('root         "C:/Ponta/www";'));
      expect(
        config,
        contains('include "C:/Ponta/vhosts/nginx/integrations/*.conf";'),
      );
      expect(
        config,
        contains('include "C:/Ponta/vhosts/nginx/*.conf";'),
      );
      expect(config, isNot(contains('# HTTPS server')));
      expect(config, isNot(contains('443')));
    });

    test('builds HTTPS server block when SSL is installed', () {
      final config = NginxConfigBuilder.buildMainConfig(
        webRoot: r'C:\Ponta\www',
        vhostsGlob: r'C:\Ponta\vhosts\nginx\*.conf',
        integrationsGlob: r'C:\Ponta\vhosts\nginx\integrations\*.conf',
        allowLanAccess: true,
        isSslInstalled: true,
        certPath: r'C:\Ponta\certs\localhost.crt',
        keyPath: r'C:\Ponta\certs\localhost.key',
      );

      expect(config, contains('listen       0.0.0.0:80;'));
      expect(config, contains('# HTTPS server'));
      expect(config, contains('listen       0.0.0.0:443 ssl;'));
      expect(
        config,
        contains('ssl_certificate      "C:/Ponta/certs/localhost.crt";'),
      );
      expect(
        config,
        contains('ssl_certificate_key  "C:/Ponta/certs/localhost.key";'),
      );
      expect(config, contains('ssl_session_cache    shared:SSL:1m;'));
      expect(config, contains('ssl_prefer_server_ciphers  on;'));
    });
  });

  group('NginxConfigBuilder.buildPhpLocation', () {
    test('generates FastCGI location directive for PHP', () {
      final config = NginxConfigBuilder.buildPhpLocation(phpPort: 9082);

      expect(config, contains(r'location ~ \.php$ {'));
      expect(config, contains('fastcgi_pass 127.0.0.1:9082;'));
      expect(config, contains('fastcgi_index index.php;'));
      expect(config, contains('include fastcgi_params;'));
      expect(
        config,
        contains(r'fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;'),
      );
    });
  });

  group('NginxConfigBuilder.buildPhpMyAdminConfig', () {
    test('generates valid phpMyAdmin integration block', () {
      final config = NginxConfigBuilder.buildPhpMyAdminConfig(
        rootDir: r'C:\Ponta\apps\phpMyAdmin',
        phpPort: 9080,
      );

      expect(config, contains('# phpMyAdmin Integration'));
      expect(config, contains('location /phpmyadmin {'));
      expect(config, contains('alias "C:/Ponta/apps/phpMyAdmin/";'));
      expect(config, contains(r'try_files $uri $uri/ /index.php?$args;'));
      expect(config, contains(r'location ~ ^/phpmyadmin/(.+\.php)$ {'));
      expect(config, contains(r'alias "C:/Ponta/apps/phpMyAdmin/$1";'));
      expect(config, contains('fastcgi_pass 127.0.0.1:9080;'));
      expect(config, contains(r'fastcgi_param SCRIPT_FILENAME $request_filename;'));
    });
  });

  group('NginxConfigBuilder.siteConfig', () {
    test('generates static site configuration', () {
      final config = NginxConfigBuilder.siteConfig(
        domain: 'mysite.local',
        rootDir: r'C:\Sites\mysite',
        siteType: 'static',
        useSsl: false,
        accessLogPath: r'C:\Sites\logs\access.log',
        errorLogPath: r'C:\Sites\logs\error.log',
        allowLanAccess: false,
      );

      expect(config, contains('server_name mysite.local;'));
      expect(config, contains('listen 127.0.0.1:80;'));
      expect(config, contains('root "C:/Sites/mysite";'));
      expect(config, contains('access_log "C:/Sites/logs/access.log";'));
      expect(config, contains('error_log "C:/Sites/logs/error.log";'));
      expect(config, isNot(contains('fastcgi_pass')));
      expect(config, isNot(contains('proxy_pass')));
    });

    test('generates PHP site configuration with SSL', () {
      final config = NginxConfigBuilder.siteConfig(
        domain: 'phpsite.local',
        rootDir: r'C:\Sites\phpsite',
        siteType: 'php',
        useSsl: true,
        phpPort: 9083,
        certPath: r'C:\Ponta\certs\phpsite.crt',
        keyPath: r'C:\Ponta\certs\phpsite.key',
        accessLogPath: r'C:\Sites\logs\access.log',
        errorLogPath: r'C:\Sites\logs\error.log',
        allowLanAccess: false,
      );

      expect(config, contains('listen 127.0.0.1:80;'));
      expect(config, contains('listen 127.0.0.1:443 ssl;'));
      expect(config, contains('fastcgi_pass 127.0.0.1:9083;'));
      expect(config, contains('ssl_certificate      "C:/Ponta/certs/phpsite.crt";'));
      expect(config, contains('ssl_certificate_key  "C:/Ponta/certs/phpsite.key";'));
    });

    test('generates reverse proxy site configuration', () {
      final config = NginxConfigBuilder.siteConfig(
        domain: 'node.local',
        rootDir: '',
        siteType: 'proxy',
        useSsl: false,
        proxyTarget: 'http://127.0.0.1:3000',
        accessLogPath: r'C:\Sites\logs\access.log',
        errorLogPath: r'C:\Sites\logs\error.log',
        allowLanAccess: true,
      );

      expect(config, contains('listen 0.0.0.0:80;'));
      expect(config, contains('proxy_pass http://127.0.0.1:3000;'));
      expect(config, contains(r'proxy_set_header Host $host;'));
      expect(config, isNot(contains('root ')));
    });
  });

  test('NginxConfigBuilder.defaultMimeTypes returns mime types', () {
    final mime = NginxConfigBuilder.defaultMimeTypes();
    expect(mime, contains('types {'));
    expect(mime, contains('text/html'));
    expect(mime, contains('application/json'));
    expect(mime, contains('image/png'));
  });
}
