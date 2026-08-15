import 'package:dev_stack/core/config/caddy_config_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CaddyConfigBuilder.mainConfig', () {
    test('disables automatic HTTPS and imports absolute vhost globs', () {
      final config = CaddyConfigBuilder.mainConfig(
        webRoot: r'C:\Ponta\www',
        bindAddress: '127.0.0.1',
        vhostsGlob: r'C:\Ponta\vhosts\caddy\*.conf',
        integrationsGlob: r'C:\Ponta\vhosts\caddy\integrations\*.conf',
        localhostAccessLogPath: r'C:\Ponta\logs\localhost\caddy_access.log',
        runtimeErrorLogPath: r'C:\Ponta\logs\caddy_error.log',
      );

      expect(config, contains('auto_https off'));
      expect(config, contains('http://localhost {'));
      expect(config, isNot(contains('https://localhost')));
      expect(
        config,
        contains('import "C:/Ponta/vhosts/caddy/integrations/*.conf"'),
      );
      expect(config, contains('import "C:/Ponta/vhosts/caddy/*.conf"'));
      expect(config, contains('exclude http.log.access'));
      expect(config, contains('C:/Ponta/logs/caddy_error.log'));
    });

    test('uses explicit local certificate for HTTPS localhost', () {
      final config = CaddyConfigBuilder.mainConfig(
        webRoot: r'C:\Ponta\www',
        bindAddress: '0.0.0.0',
        vhostsGlob: r'C:\Ponta\vhosts\caddy\*.conf',
        integrationsGlob: r'C:\Ponta\vhosts\caddy\integrations\*.conf',
        localhostAccessLogPath: r'C:\Ponta\logs\localhost\caddy_access.log',
        runtimeErrorLogPath: r'C:\Ponta\logs\caddy_error.log',
        certPath: r'C:\Ponta\certs\localhost.crt',
        keyPath: r'C:\Ponta\certs\localhost.key',
      );

      // Caddy rejects an explicit http:// address mixed with a tls
      // directive, so TLS mode must emit separate HTTP and HTTPS blocks.
      expect(config, contains('http://localhost {'));
      expect(config, contains('https://localhost {'));
      expect(config, isNot(contains('http://localhost, https://localhost')));
      expect(config, contains('bind 0.0.0.0'));
      expect(
        config,
        contains(
          'tls "C:/Ponta/certs/localhost.crt" '
          '"C:/Ponta/certs/localhost.key"',
        ),
      );
      expect('tls '.allMatches(config).length, 1);
    });
  });

  group('CaddyConfigBuilder.siteConfig', () {
    test('builds static HTTP site with per-site access log', () {
      final config = CaddyConfigBuilder.siteConfig(
        domain: 'static.test',
        bindAddress: '127.0.0.1',
        rootDir: r'C:\Sites\static',
        siteType: 'static',
        useSsl: false,
        accessLogPath: r'C:\Ponta\logs\static.test\caddy_access.log',
      );

      expect(config, startsWith('http://static.test {'));
      expect(config, contains('root * "C:/Sites/static"'));
      expect(config, contains('file_server'));
      expect(config, isNot(contains('php_fastcgi')));
      expect(config, isNot(contains('reverse_proxy')));
    });

    test('builds PHP site with FastCGI port', () {
      final config = CaddyConfigBuilder.siteConfig(
        domain: 'php.test',
        bindAddress: '127.0.0.1',
        rootDir: r'C:\Sites\php',
        siteType: 'php',
        phpPort: 9084,
        useSsl: false,
        accessLogPath: r'C:\Ponta\logs\php.test\caddy_access.log',
      );

      expect(config, contains('php_fastcgi 127.0.0.1:9084'));
      expect(config, contains('file_server'));
    });

    test('builds reverse proxy without document-root directives', () {
      final config = CaddyConfigBuilder.siteConfig(
        domain: 'proxy.test',
        bindAddress: '127.0.0.1',
        rootDir: r'C:\Sites\unused',
        siteType: 'proxy',
        proxyTarget: 'http://127.0.0.1:3000',
        useSsl: false,
        accessLogPath: r'C:\Ponta\logs\proxy.test\caddy_access.log',
      );

      expect(config, contains('reverse_proxy http://127.0.0.1:3000'));
      expect(config, isNot(contains('root *')));
      expect(config, isNot(contains('file_server')));
    });

    test('serves explicit HTTP and HTTPS with supplied certificate', () {
      final config = CaddyConfigBuilder.siteConfig(
        domain: 'secure.test',
        bindAddress: '0.0.0.0',
        rootDir: r'C:\Sites\secure',
        siteType: 'static',
        useSsl: true,
        certPath: r'C:\Ponta\certs\secure.test.crt',
        keyPath: r'C:\Ponta\certs\secure.test.key',
        accessLogPath: r'C:\Ponta\logs\secure.test\caddy_access.log',
      );

      // Separate blocks: Caddy refuses http:// + https:// addresses
      // sharing one block with a tls directive.
      expect(config, startsWith('http://secure.test {'));
      expect(config, contains('https://secure.test {'));
      expect(config, contains('bind 0.0.0.0'));
      expect(config, contains('tls "C:/Ponta/certs/secure.test.crt"'));
      expect('tls '.allMatches(config).length, 1);
    });

    test('rejects incomplete type-specific arguments', () {
      expect(
        () => CaddyConfigBuilder.siteConfig(
          domain: 'php.test',
          bindAddress: '127.0.0.1',
          rootDir: r'C:\Sites\php',
          siteType: 'php',
          useSsl: false,
          accessLogPath: r'C:\Ponta\logs\php.test\caddy_access.log',
        ),
        throwsArgumentError,
      );
      expect(
        () => CaddyConfigBuilder.siteConfig(
          domain: 'secure.test',
          bindAddress: '127.0.0.1',
          rootDir: r'C:\Sites\secure',
          siteType: 'static',
          useSsl: true,
          accessLogPath: r'C:\Ponta\logs\secure.test\caddy_access.log',
        ),
        throwsArgumentError,
      );
    });
  });

  test('builds phpMyAdmin route snippet', () {
    final config = CaddyConfigBuilder.phpMyAdminIntegration(
      rootDir: r'C:\Ponta\apps\phpMyAdmin',
      phpPort: 9084,
    );

    expect(config, contains('handle_path /phpmyadmin*'));
    expect(config, contains('root * "C:/Ponta/apps/phpMyAdmin"'));
    expect(config, contains('php_fastcgi 127.0.0.1:9084'));
    expect(config, contains('file_server'));
  });
}
