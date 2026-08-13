import 'package:dev_stack/shared/widgets/code_editor/language_for_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_highlight/languages/apache.dart';
import 'package:re_highlight/languages/ini.dart';
import 'package:re_highlight/languages/json.dart';
import 'package:re_highlight/languages/nginx.dart';
import 'package:re_highlight/languages/php.dart';
import 'package:re_highlight/languages/plaintext.dart';
import 'package:re_highlight/languages/yaml.dart';

void main() {
  group('languageForConfigPath', () {
    test('maps nginx config to the nginx mode', () {
      final mode = languageForConfigPath(
        r'C:\apps\nginx\conf\nginx.conf',
      );
      expect(mode, same(langNginx));
    });

    test('maps apache config to the apache mode', () {
      final mode = languageForConfigPath(
        r'C:\apps\Apache24\conf\httpd.conf',
      );
      expect(mode, same(langApache));
    });

    test('maps php.ini to the ini mode', () {
      expect(languageForConfigPath(r'C:\apps\php\php.ini'), same(langIni));
    });

    test('maps mongod.cfg and redis conf to the ini mode', () {
      expect(languageForConfigPath(r'C:\apps\mongodb\mongod.cfg'), same(langIni));
      expect(
        languageForConfigPath(r'C:\apps\redis\redis.windows.conf'),
        same(langIni),
      );
    });

    test('maps config.toml to the ini mode (no dedicated toml mode)', () {
      expect(languageForConfigPath(r'C:\apps\meili\config.toml'), same(langIni));
    });

    test('maps json configs to the json mode', () {
      expect(
        languageForConfigPath(r'C:\data\rustfs\config.json'),
        same(langJson),
      );
    });

    test('maps yaml configs to the yaml mode', () {
      expect(
        languageForConfigPath(r'C:\apps\es\config\elasticsearch.yml'),
        same(langYaml),
      );
      expect(languageForConfigPath(r'C:\foo\bar.yaml'), same(langYaml));
    });

    test('maps php config.inc.php to the php mode', () {
      expect(
        languageForConfigPath(r'C:\apps\phpmyadmin\config.inc.php'),
        same(langPhp),
      );
    });

    test('maps the Windows hosts file to the plaintext mode', () {
      expect(
        languageForConfigPath(r'C:\Windows\System32\drivers\etc\hosts'),
        same(langPlaintext),
      );
    });

    test('falls back to plaintext for unknown/extensionless paths', () {
      expect(languageForConfigPath(r'C:\some\random\file'), same(langPlaintext));
      expect(languageForConfigPath('noext'), same(langPlaintext));
      expect(languageForConfigPath(''), same(langPlaintext));
    });
  });
}
