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
  // Normalize backslashes to forward slashes so Windows paths resolve their
  // basename correctly on Linux/macOS runners.
  final normalized = path.replaceAll(r'\', '/').toLowerCase();
  final name = p.basename(normalized);

  // Path or file-name based webserver mapping (including vhosts).
  if (name == 'nginx.conf' || normalized.contains('/nginx/') || name.startsWith('nginx_')) {
    return langNginx;
  }
  if (name == 'httpd.conf' || name == 'apache.conf' || normalized.contains('/apache/') || name.startsWith('apache_')) {
    return langApache;
  }
  if (name == 'caddyfile' || normalized.contains('/caddy/') || name.startsWith('caddy_')) {
    return langPlaintext;
  }
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
