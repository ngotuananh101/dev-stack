import 'package:dev_stack/core/config/apache_config_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApacheConfigBuilder.buildMainConfig', () {
    test('updates ServerRoot, DocumentRoot, Directory permissions, Listeners, and global vhosts', () {
      const initialHttpd = '''
Define SRVROOT "c:/Apache24"
ServerRoot "\${SRVROOT}"
Listen 80
DocumentRoot "c:/Apache24/htdocs"
<Directory "c:/Apache24/htdocs">
    Options Indexes FollowSymLinks
    AllowOverride None
    Require all granted
</Directory>
#ServerName www.example.com:80
''';

      final updated = ApacheConfigBuilder.buildMainConfig(
        initialContent: initialHttpd,
        serverRoot: r'C:\Ponta\apps\apache\2.4.58',
        documentRoot: r'C:\Ponta\www',
        vhostsGlob: r'C:\Ponta\vhosts\apache\*.conf',
        allowLanAccess: false,
        isSslInstalled: false,
      );

      expect(
        updated,
        contains('Define SRVROOT "C:/Ponta/apps/apache/2.4.58"'),
      );
      expect(updated, contains('DocumentRoot "C:/Ponta/www"'));
      expect(updated, contains('<Directory "C:/Ponta/www">'));
      expect(updated, contains('Options Indexes FollowSymLinks'));
      expect(updated, contains('AllowOverride All'));
      expect(updated, contains('Require all granted'));
      expect(updated, contains('Listen 127.0.0.1:80'));
      expect(updated, isNot(contains('Listen 127.0.0.1:443')));
      expect(updated, contains('ServerName localhost:80'));
      expect(
        updated,
        contains('IncludeOptional "C:/Ponta/vhosts/apache/*.conf"'),
      );
    });

    test('configures mod_ssl and mod_proxy when SSL is installed', () {
      const initialHttpd = '''
Define SRVROOT "c:/Apache24"
ServerRoot "\${SRVROOT}"
Listen 80
DocumentRoot "c:/Apache24/htdocs"
<Directory "c:/Apache24/htdocs">
</Directory>
#LoadModule ssl_module modules/mod_ssl.so
#LoadModule socache_shmcb_module modules/mod_socache_shmcb.so
#LoadModule proxy_module modules/mod_proxy.so
#LoadModule proxy_fcgi_module modules/mod_proxy_fcgi.so
''';

      final updated = ApacheConfigBuilder.buildMainConfig(
        initialContent: initialHttpd,
        serverRoot: r'C:\Ponta\apps\apache\2.4.58',
        documentRoot: r'C:\Ponta\www',
        vhostsGlob: r'C:\Ponta\vhosts\apache\*.conf',
        allowLanAccess: true,
        isSslInstalled: true,
        certPath: r'C:\Ponta\certs\localhost.crt',
        keyPath: r'C:\Ponta\certs\localhost.key',
      );

      expect(updated, contains('LoadModule ssl_module modules/mod_ssl.so'));
      expect(
        updated,
        contains('LoadModule socache_shmcb_module modules/mod_socache_shmcb.so'),
      );
      expect(updated, contains('LoadModule proxy_module modules/mod_proxy.so'));
      expect(
        updated,
        contains('LoadModule proxy_fcgi_module modules/mod_proxy_fcgi.so'),
      );
      expect(updated, contains('Listen 0.0.0.0:80'));
      expect(updated, contains('Listen 0.0.0.0:443'));
      expect(updated, contains('# Ponta SSL Virtual Host'));
      expect(updated, contains('<VirtualHost 0.0.0.0:443>'));
      expect(updated, contains('ServerName localhost:443'));
      expect(updated, contains('SSLEngine on'));
      expect(
        updated,
        contains('SSLCertificateFile "C:/Ponta/certs/localhost.crt"'),
      );
      expect(
        updated,
        contains('SSLCertificateKeyFile "C:/Ponta/certs/localhost.key"'),
      );
    });
  });

  group('ApacheConfigBuilder.buildPhpFpmConfig', () {
    test('generates FastCGI SetHandler for PHP', () {
      final config = ApacheConfigBuilder.buildPhpFpmConfig(phpPort: 9000);

      expect(config, contains(r'<FilesMatch \.php$>'));
      expect(config, contains('SetHandler "proxy:fcgi://127.0.0.1:9000"'));
      expect(config, contains('</FilesMatch>'));
    });
  });

  group('ApacheConfigBuilder.buildPhpMyAdminConfig', () {
    test('generates valid alias and FastCGI handler block', () {
      const pmaPathUnix = '/opt/ponta/apps/phpmyadmin';
      final config = ApacheConfigBuilder.buildPhpMyAdminConfig(
        pmaPathUnix,
        phpPort: 9000,
      );

      expect(config, contains('# phpMyAdmin Configuration'));
      expect(config, contains('Alias /phpmyadmin "/opt/ponta/apps/phpmyadmin/"'));
      expect(config, contains('<Directory "/opt/ponta/apps/phpmyadmin/">'));
      expect(config, contains('Options Indexes FollowSymLinks MultiViews'));
      expect(config, contains('AllowOverride All'));
      expect(config, contains('Require all granted'));
      expect(config, contains(r'<FilesMatch \.php$>'));
      expect(config, contains('SetHandler "proxy:fcgi://127.0.0.1:9000"'));
    });
  });

  group('ApacheConfigBuilder.siteConfig', () {
    test('generates static site VirtualHost', () {
      final config = ApacheConfigBuilder.siteConfig(
        domain: 'mysite.local',
        rootDir: r'C:\Sites\mysite',
        siteType: 'static',
        useSsl: false,
        accessLogPath: r'C:\Sites\logs\apache_access.log',
        errorLogPath: r'C:\Sites\logs\apache_error.log',
        allowLanAccess: false,
      );

      expect(config, contains('<VirtualHost 127.0.0.1:80>'));
      expect(config, contains('ServerName mysite.local'));
      expect(config, contains('DocumentRoot "C:/Sites/mysite"'));
      expect(config, contains('<Directory "C:/Sites/mysite">'));
      expect(config, contains('CustomLog "C:/Sites/logs/apache_access.log" combined'));
      expect(config, contains('ErrorLog "C:/Sites/logs/apache_error.log"'));
      expect(config, isNot(contains('SetHandler')));
      expect(config, isNot(contains('ProxyPass')));
    });

    test('generates PHP site VirtualHost with SSL', () {
      final config = ApacheConfigBuilder.siteConfig(
        domain: 'phpsite.local',
        rootDir: r'C:\Sites\phpsite',
        siteType: 'php',
        useSsl: true,
        phpPort: 9083,
        certPath: r'C:\Ponta\certs\phpsite.crt',
        keyPath: r'C:\Ponta\certs\phpsite.key',
        accessLogPath: r'C:\Sites\logs\apache_access.log',
        errorLogPath: r'C:\Sites\logs\apache_error.log',
        allowLanAccess: false,
      );

      expect(config, contains('<VirtualHost 127.0.0.1:80>'));
      expect(config, contains('<IfModule mod_ssl.c>'));
      expect(config, contains('<VirtualHost 127.0.0.1:443>'));
      expect(config, contains('SSLEngine on'));
      expect(config, contains('SSLCertificateFile "C:/Ponta/certs/phpsite.crt"'));
      expect(config, contains('SSLCertificateKeyFile "C:/Ponta/certs/phpsite.key"'));
      expect(config, contains('SetHandler "proxy:fcgi://127.0.0.1:9083"'));
    });

    test('generates reverse proxy site VirtualHost', () {
      final config = ApacheConfigBuilder.siteConfig(
        domain: 'node.local',
        rootDir: '',
        siteType: 'proxy',
        useSsl: false,
        proxyTarget: 'http://127.0.0.1:3000',
        accessLogPath: r'C:\Sites\logs\apache_access.log',
        errorLogPath: r'C:\Sites\logs\apache_error.log',
        allowLanAccess: true,
      );

      expect(config, contains('<VirtualHost 0.0.0.0:80>'));
      expect(config, contains('ProxyPreserveHost On'));
      expect(config, contains('ProxyPass / http://127.0.0.1:3000/'));
      expect(config, contains('ProxyPassReverse / http://127.0.0.1:3000/'));
      expect(config, isNot(contains('DocumentRoot')));
    });
  });
}
