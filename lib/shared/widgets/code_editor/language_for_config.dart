import 'package:path/path.dart' as p;
import 'package:re_highlight/re_highlight.dart';
import 'package:re_highlight/languages/apache.dart';
import 'package:re_highlight/languages/ini.dart';
import 'package:re_highlight/languages/json.dart';
import 'package:re_highlight/languages/nginx.dart';
import 'package:re_highlight/languages/php.dart';
import 'package:re_highlight/languages/plaintext.dart';
import 'package:re_highlight/languages/yaml.dart';

/// Picks a `re_highlight` syntax [Mode] for a config file path, used by the
/// in-app code editor. The mapping is by file name + extension because the
/// same extension can mean different things (`.conf` is nginx.conf vs
/// httpd.conf), and some configs carry no language-specific extension at all
/// (the Windows `hosts` file).
///
/// Returns [langPlaintext] as a safe fallback for unknown paths so the editor
/// still renders without a highlight crash. Returning `null` would leave the
/// editor theme-less; an explicit plaintext mode is more predictable.
Mode languageForConfigPath(String path) {
  final name = p.basename(path).toLowerCase();

  // File-name based mapping (extension alone is ambiguous).
  if (name == 'nginx.conf') return langNginx;
  if (name == 'httpd.conf' || name == 'apache.conf') return langApache;
  if (name == 'hosts') return langPlaintext;
  if (name.endsWith('.php') || name.endsWith('.inc.php')) return langPhp;

  final ext = p.extension(name);

  switch (ext) {
    case '.ini':
    case '.cfg':
    case '.conf':
    case '.toml':
    case '.properties':
      // .conf is ambiguous; .ini/.cfg/.toml are ini-family. redis/mongod/
      // meilisearch configs all read fine under the ini highlighter.
      return langIni;
    case '.json':
      return langJson;
    case '.yml':
    case '.yaml':
      return langYaml;
    case '.php':
      return langPhp;
    default:
      return langPlaintext;
  }
}
