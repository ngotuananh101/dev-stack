import 'package:dev_stack/core/config/apache_config_builder.dart';
import 'package:dev_stack/core/config/caddy_config_builder.dart';
import 'package:dev_stack/core/config/nginx_config_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CLI Site Configuration Builders', () {
    test('Nginx siteConfig for CLI generates proxy_pass and WebSocket upgrade headers', () {
      final config = NginxConfigBuilder.siteConfig(
        domain: 'nodeapp.test',
        rootDir: '/projects/nodeapp',
        siteType: 'cli',
        useSsl: false,
        cliPort: 3000,
        accessLogPath: '/logs/access.log',
        errorLogPath: '/logs/error.log',
        allowLanAccess: false,
      );

      expect(config, contains('proxy_pass http://127.0.0.1:3000;'));
      expect(config, contains('proxy_http_version 1.1;'));
      expect(config, contains(r'proxy_set_header Upgrade $http_upgrade;'));
      expect(config, contains('proxy_set_header Connection "upgrade";'));
      expect(config, contains(r'proxy_set_header Host $host;'));
      expect(config, contains(r'proxy_read_timeout 86400s;'));
    });

    test('Apache siteConfig for CLI generates WebSocket rewrite rule and ProxyPassReverse', () {
      final config = ApacheConfigBuilder.siteConfig(
        domain: 'nodeapp.test',
        rootDir: '/projects/nodeapp',
        siteType: 'cli',
        useSsl: false,
        cliPort: 3000,
        accessLogPath: '/logs/access.log',
        errorLogPath: '/logs/error.log',
        allowLanAccess: false,
      );

      expect(config, contains('RewriteEngine On'));
      expect(config, contains('RewriteCond %{HTTP:Upgrade} =websocket [NC]'));
      expect(config, contains('RewriteRule /(.*) ws://127.0.0.1:3000/\$1 [P,L]'));
      expect(config, contains('RewriteCond %{HTTP:Upgrade} !=websocket [NC]'));
      expect(config, contains('RewriteRule /(.*) http://127.0.0.1:3000/\$1 [P,L]'));
      expect(config, contains('ProxyPassReverse / http://127.0.0.1:3000/'));
    });

    test('Caddy siteConfig for CLI generates reverse_proxy to 127.0.0.1:port', () {
      final config = CaddyConfigBuilder.siteConfig(
        domain: 'nodeapp.test',
        bindAddress: '127.0.0.1',
        rootDir: '/projects/nodeapp',
        siteType: 'cli',
        cliPort: 3000,
        useSsl: false,
        accessLogPath: '/logs/access.log',
      );

      expect(config, contains('reverse_proxy 127.0.0.1:3000'));
    });
  });
}
