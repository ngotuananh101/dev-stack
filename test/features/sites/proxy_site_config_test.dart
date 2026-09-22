import 'package:dev_stack/core/config/apache_config_builder.dart';
import 'package:dev_stack/core/config/caddy_config_builder.dart';
import 'package:dev_stack/core/config/nginx_config_builder.dart';
import 'package:dev_stack/features/sites/data/sites_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Proxy Site Configuration and Validation', () {
    test('Nginx siteConfig for proxy works with empty rootDir', () {
      final config = NginxConfigBuilder.siteConfig(
        domain: 'proxy.test',
        rootDir: '',
        siteType: 'proxy',
        useSsl: false,
        proxyTarget: 'http://127.0.0.1:3000',
        accessLogPath: '/logs/access.log',
        errorLogPath: '/logs/error.log',
        allowLanAccess: false,
      );

      expect(config, contains('proxy_pass http://127.0.0.1:3000;'));
      expect(config, isNot(contains('root ')));
    });

    test('Apache siteConfig for proxy works with empty rootDir', () {
      final config = ApacheConfigBuilder.siteConfig(
        domain: 'proxy.test',
        rootDir: '',
        siteType: 'proxy',
        useSsl: false,
        proxyTarget: 'http://127.0.0.1:3000',
        accessLogPath: '/logs/access.log',
        errorLogPath: '/logs/error.log',
        allowLanAccess: false,
      );

      expect(config, contains('ProxyPass / http://127.0.0.1:3000/'));
      expect(config, contains('ProxyPassReverse / http://127.0.0.1:3000/'));
      expect(config, isNot(contains('DocumentRoot')));
    });

    test('Caddy siteConfig for proxy works with empty rootDir', () {
      final config = CaddyConfigBuilder.siteConfig(
        domain: 'proxy.test',
        bindAddress: '127.0.0.1',
        rootDir: '',
        siteType: 'proxy',
        proxyTarget: 'http://127.0.0.1:3000',
        useSsl: false,
        accessLogPath: '/logs/access.log',
      );

      expect(config, contains('reverse_proxy http://127.0.0.1:3000'));
      expect(config, isNot(contains('root *')));
      expect(config, isNot(contains('file_server')));
    });

    test('Proxy target validation accepts valid URLs and rejects malicious input', () {
      expect(
        Sites.validateProxyTarget('http://localhost:5000'),
        'http://localhost:5000',
      );
      expect(
        () => Sites.validateProxyTarget(''),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => Sites.validateProxyTarget('http://localhost:5000;\nrm -rf /'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Non-empty rootDir validation prevents directive injection if provided', () {
      // If a proxy site supplies a rootDir, unsafe characters are still caught
      expect(
        () => Sites.validateRootDir('C:\\path"with"quotes'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => Sites.validateRootDir('C:\\path\nwith\nnewlines'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
