import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

/// A tiny producer-compatible bundle, with a real scan-file manager.
Directory createPhpBundleFixture(Directory parent) {
  final root = Directory(p.join(parent.path, 'php bundle'))..createSync();
  for (final dir in [
    'bin',
    'libexec',
    'etc/cli/conf.d',
    'etc/fpm/conf.d',
    'lib/php/extensions',
  ]) {
    Directory(p.join(root.path, dir)).createSync(recursive: true);
  }
  for (final file in [
    'bin/php',
    'bin/php-fpm',
    'libexec/php',
    'libexec/php-fpm',
  ]) {
    File(p.join(root.path, file)).writeAsStringSync('#!/bin/sh\nexit 0\n');
  }
  File(
    p.join(root.path, 'etc/php.ini'),
  ).writeAsStringSync('memory_limit = 128M\n;openssl.cafile =\n');
  final bytes = utf8.encode('fixture module');
  File(
    p.join(root.path, 'lib/php/extensions/redis.so'),
  ).writeAsBytesSync(bytes);
  File(p.join(root.path, 'bin/php-ext')).writeAsStringSync(r'''#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
[ "$2" = redis ] && [ "$3" = all ] || exit 2
for sapi in cli fpm; do
  file="$root/etc/$sapi/conf.d/50-redis.ini"
  case "$1" in
    enable) printf 'extension=redis.so\n' > "$file.tmp"; mv "$file.tmp" "$file" ;;
    disable) rm -f "$file" ;;
    *) exit 2 ;;
  esac
done
''');
  final manifest = {
    'schema_version': 1,
    'runtime': 'php',
    'architecture': 'x86_64',
    'target': 'glibc',
    'profile': 'full',
    'verification': 'PASSED',
    'php': {
      'version': '8.4.27',
      'static_modules': ['Core', 'PDO', 'Zend OPcache'],
    },
    'paths': {
      'cli': 'bin/php',
      'fpm': 'bin/php-fpm',
      'extension_manager': 'bin/php-ext',
      'cli_binary': 'libexec/php',
      'fpm_binary': 'libexec/php-fpm',
      'php_ini': 'etc/php.ini',
      'cli_scan_dir': 'etc/cli/conf.d',
      'fpm_scan_dir': 'etc/fpm/conf.d',
      'extension_dir': 'lib/php/extensions',
    },
    'shared_modules': [
      {
        'name': 'redis',
        'directive': 'extension',
        'path': 'lib/php/extensions/redis.so',
        'sha256': sha256.convert(bytes).toString(),
        'enabled_by_default': {'cli': false, 'fpm': false},
      },
    ],
  };
  File(
    p.join(root.path, 'manifest.json'),
  ).writeAsStringSync(jsonEncode(manifest));
  return root;
}

void editBundleManifest(
  Directory root,
  void Function(Map<String, dynamic>) edit,
) {
  final file = File(p.join(root.path, 'manifest.json'));
  final manifest = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  edit(manifest);
  file.writeAsStringSync(jsonEncode(manifest));
}
