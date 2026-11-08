import 'package:dev_stack/core/config/apache_config_builder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

RegExp _apacheGlobToRegExp(String glob) {
  var pattern = glob;
  pattern = pattern.replaceAllMapped(
    RegExp(r'\[!(.*?)\]'),
    (m) => '[^${m[1]}]',
  );
  pattern = pattern.replaceAll('.', r'\.');
  pattern = pattern.replaceAll('*', '.*');
  pattern = pattern.replaceAll('?', '.');
  return RegExp('^$pattern\$');
}

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

    test('enables proxy modules even when SSL is not installed', () {
      const initialHttpd = '''
Define SRVROOT "c:/Apache24"
ServerRoot "\${SRVROOT}"
Listen 80
ServerRoot "\${SRVROOT}"
DocumentRoot "c:/Apache24/htdocs"
#LoadModule proxy_module modules/mod_proxy.so
#LoadModule proxy_fcgi_module modules/mod_proxy_fcgi.so
#LoadModule proxy_http_module modules/mod_proxy_http.so
#LoadModule alias_module modules/mod_alias.so
#LoadModule ssl_module modules/mod_ssl.so
#LoadModule socache_shmcb_module modules/mod_socache_shmcb.so
''';

      final updated = ApacheConfigBuilder.buildMainConfig(
        initialContent: initialHttpd,
        serverRoot: r'C:\Ponta\apps\apache\2.4.58',
        documentRoot: r'C:\Ponta\www',
        vhostsGlob: r'C:\Ponta\vhosts\apache\*.conf',
        allowLanAccess: false,
        isSslInstalled: false,
      );

      // Proxy modules must be enabled regardless of SSL
      expect(updated, contains('LoadModule proxy_module modules/mod_proxy.so'));
      expect(
        updated,
        contains('LoadModule proxy_fcgi_module modules/mod_proxy_fcgi.so'),
      );
      expect(
        updated,
        contains('LoadModule proxy_http_module modules/mod_proxy_http.so'),
      );
      expect(updated, contains('LoadModule alias_module modules/mod_alias.so'));
      // SSL modules must remain commented when SSL is not installed
      expect(updated, contains('#LoadModule ssl_module'));
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

  group('ApacheConfigBuilder.buildBundleConfig', () {
    const producerConf = '''
Define SRVROOT "\${APACHE_SERVER_ROOT}"
ServerRoot "\${SRVROOT}"
Listen 80
LoadModule mpm_event_module modules/mod_mpm_event.so
<IfModule unixd_module>
User daemon
Group daemon
</IfModule>
DocumentRoot "\${SRVROOT}/htdocs"
<Directory "\${SRVROOT}/htdocs">
    Require all granted
</Directory>
''';

    test('builds a runnable config from the producer bundle conf', () {
      final out = ApacheConfigBuilder.buildBundleConfig(
        initialContent: producerConf,
        serverRoot: '/opt/apps/apache/2.4.70',
        documentRoot: '/opt/www',
        vhostsDir: '/opt/vhosts/apache',
        logsDir: '/opt/logs',
        allowLanAccess: false,
        isSslInstalled: false,
      );
      expect(out, contains('Define SRVROOT "/opt/apps/apache/2.4.70"'));
      expect(out, contains('ServerRoot "\${SRVROOT}"'));
      expect(out, contains('DocumentRoot "/opt/www"'));
      expect(out, contains('LoadModule unixd_module modules/mod_unixd.so'));
      expect(out, contains('PidFile "/opt/logs/httpd.pid"'));
      expect(out, contains('ErrorLog "/opt/logs/apache_error.log"'));
      expect(out, contains('IncludeOptional "/opt/vhosts/apache/[a-zA-Z0-9]*.conf"'));
      expect(out, isNot(contains('IncludeOptional "/opt/vhosts/apache/[!h]*.conf"')));
      expect(out, isNot(contains('IncludeOptional "/opt/vhosts/apache/*.conf"')));
      expect(RegExp(r'^Listen ', multiLine: true).allMatches(out).length, 1);
      expect(out, contains('Listen 127.0.0.1:80'));
    });

    test('IncludeOptional glob matches hello.test.conf and excludes _httpd.conf', () {
      final out = ApacheConfigBuilder.buildBundleConfig(
        initialContent: producerConf,
        serverRoot: '/opt/apps/apache/2.4.70',
        documentRoot: '/opt/www',
        vhostsDir: '/opt/vhosts/apache',
        logsDir: '/opt/logs',
        allowLanAccess: false,
        isSslInstalled: false,
      );
      final match = RegExp(r'IncludeOptional\s+"([^"]+)"').firstMatch(out);
      expect(match, isNotNull);
      final glob = p.posix.basename(match!.group(1)!);
      final regex = _apacheGlobToRegExp(glob);

      // Must match domains starting with 'h' (e.g. hello.test, hotel.local)
      expect(regex.hasMatch('hello.test.conf'), isTrue,
          reason: 'Sites starting with "h" must not be excluded');
      expect(regex.hasMatch('hotel.local.conf'), isTrue,
          reason: 'Sites starting with "h" must not be excluded');
      // Must match domains starting with digits or other letters
      expect(regex.hasMatch('123site.test.conf'), isTrue);
      expect(regex.hasMatch('mysite.local.conf'), isTrue);

      // Must NOT match the main config file (_httpd.conf)
      expect(regex.hasMatch(ApacheConfigBuilder.mainConfigFileName), isFalse,
          reason: 'The main config file must not match its own include glob');
    });

    test('replaces existing ErrorLog', () {
      const confWithErrorLog = '''
Define SRVROOT "\${APACHE_SERVER_ROOT}"
ServerRoot "\${SRVROOT}"
Listen 80
ErrorLog "logs/error_log"
DocumentRoot "\${SRVROOT}/htdocs"
<Directory "\${SRVROOT}/htdocs">
    Require all granted
</Directory>
''';
      final out = ApacheConfigBuilder.buildBundleConfig(
        initialContent: confWithErrorLog,
        serverRoot: '/opt/apps/apache/2.4.70',
        documentRoot: '/opt/www',
        vhostsDir: '/opt/vhosts/apache',
        logsDir: '/opt/logs',
        allowLanAccess: false,
        isSslInstalled: false,
      );
      expect(out, contains('ErrorLog "/opt/logs/apache_error.log"'));
      expect(out, isNot(contains('logs/error_log')));
      expect(RegExp(r'^ErrorLog ', multiLine: true).allMatches(out).length, 1);
    });

    test('prependDirectives is idempotent', () {
      const conf = '''
Define SRVROOT "/opt/apps/apache/2.4.70"
ServerRoot "\${SRVROOT}"
Listen 80
''';
      final directives = [
        'PidFile "/opt/logs/httpd.pid"',
        'ErrorLog "/opt/logs/apache_error.log"',
        'LoadModule unixd_module modules/mod_unixd.so',
      ];
      final first = ApacheConfigBuilder.prependDirectives(conf, directives);
      final second = ApacheConfigBuilder.prependDirectives(first, directives);
      expect(second, equals(first));
    });

    test('prependDirectives uncomments commented-out LoadModule', () {
      const conf = '''
Define SRVROOT "/opt/apps/apache/2.4.70"
ServerRoot "\${SRVROOT}"
# LoadModule unixd_module modules/mod_unixd.so
Listen 80
''';
      final directives = [
        'LoadModule unixd_module modules/mod_unixd.so',
      ];
      final out = ApacheConfigBuilder.prependDirectives(conf, directives);
      expect(out, contains('LoadModule unixd_module modules/mod_unixd.so'));
      expect(out, isNot(contains('# LoadModule unixd_module')));
      expect(
        RegExp(r'^LoadModule\s+unixd_module', multiLine: true)
            .allMatches(out)
            .length,
        1,
      );
    });

    test('prependDirectives avoids duplicate LoadModule with irregular spacing', () {
      const conf = '''
Define SRVROOT "/opt/apps/apache/2.4.70"
ServerRoot "\${SRVROOT}"
LoadModule   unixd_module   modules/mod_unixd.so
Listen 80
''';
      final directives = [
        'LoadModule unixd_module modules/mod_unixd.so',
      ];
      final out = ApacheConfigBuilder.prependDirectives(conf, directives);
      expect(out, contains('LoadModule unixd_module modules/mod_unixd.so'));
      expect(
        RegExp(r'LoadModule\s+unixd_module', multiLine: true)
            .allMatches(out)
            .length,
        1,
      );
    });

    test('prependDirectives ignores commented-out ErrorLog and inserts active line', () {
      const conf = '''
Define SRVROOT "/opt/apps/apache/2.4.70"
ServerRoot "\${SRVROOT}"
# ErrorLog "logs/error.log"
Listen 80
''';
      final directives = [
        'ErrorLog "/opt/logs/apache_error.log"',
      ];
      final out = ApacheConfigBuilder.prependDirectives(conf, directives);
      expect(out, contains('ErrorLog "/opt/logs/apache_error.log"'));
      expect(out, contains('# ErrorLog "logs/error.log"'));
      expect(
        RegExp(r'^ErrorLog ', multiLine: true).allMatches(out).length,
        1,
      );
    });
  });
}
