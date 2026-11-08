import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Builds a minimal producer-compatible Apache bundle fixture.
Directory createApacheBundleFixture(Directory parent) {
  final root = Directory(p.join(parent.path, 'apache bundle'))
    ..createSync(recursive: true);
  for (final dir in ['bin', 'libexec/bin', 'conf']) {
    Directory(p.join(root.path, dir)).createSync(recursive: true);
  }
  for (final file in ['bin/httpd', 'bin/apachectl']) {
    File(p.join(root.path, file)).writeAsStringSync('#!/bin/sh\nexit 0\n');
  }
  File(p.join(root.path, 'libexec/bin/httpd')).writeAsStringSync('ELF binary');

  File(p.join(root.path, 'conf/httpd.conf')).writeAsStringSync('''
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
''');

  final manifest = {
    'schema_version': 1,
    'runtime': 'apache',
    'target': 'musl-dynamic',
    'apache': {'version': '2.4.70'},
    'launchers': ['apachectl', 'httpd'],
  };
  File(
    p.join(root.path, 'manifest.json'),
  ).writeAsStringSync(jsonEncode(manifest));
  return root;
}

/// Builds a minimal producer-compatible PostgreSQL bundle fixture.
Directory createPostgresqlBundleFixture(Directory parent) {
  final root = Directory(p.join(parent.path, 'postgresql bundle'))
    ..createSync(recursive: true);
  for (final dir in ['bin', 'libexec/bin']) {
    Directory(p.join(root.path, dir)).createSync(recursive: true);
  }
  for (final file in ['bin/initdb', 'bin/postgres', 'bin/psql']) {
    File(p.join(root.path, file)).writeAsStringSync('#!/bin/sh\nexit 0\n');
  }
  File(
    p.join(root.path, 'libexec/bin/postgres'),
  ).writeAsStringSync('ELF binary');
  File(p.join(root.path, 'libexec/bin/initdb')).writeAsStringSync('ELF binary');

  final manifest = {
    'schema_version': 1,
    'runtime': 'postgresql',
    'target': 'musl-dynamic',
    'postgresql': {'version': '18.6', 'major': '18'},
    'binaries': [
      {'path': 'libexec/bin/postgres'},
      {'path': 'libexec/bin/initdb'},
    ],
  };
  File(
    p.join(root.path, 'manifest.json'),
  ).writeAsStringSync(jsonEncode(manifest));
  return root;
}
