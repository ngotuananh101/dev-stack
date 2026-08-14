import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalog contains stable Windows amd64 Caddy releases', () async {
    final raw = await File('assets/data/apps.json').readAsString();
    final catalog = jsonDecode(raw) as Map<String, dynamic>;
    final apps = (catalog['apps'] as List).cast<Map<String, dynamic>>();
    final caddy = apps.singleWhere((app) => app['id'] == 'caddy');

    expect(caddy['name'], 'Caddy');
    expect(caddy['category'], 'webserver');
    expect(caddy['group_name'], 'webserver');
    expect(caddy['exec_file'], 'caddy.exe');
    expect(caddy['cli_file'], 'caddy.exe');
    expect(caddy['repo'], 'caddyserver/caddy');
    expect(caddy['versions'], <String, String>{
      '2.11.4':
          'https://github.com/caddyserver/caddy/releases/download/v2.11.4/caddy_2.11.4_windows_amd64.zip',
      '2.11.3':
          'https://github.com/caddyserver/caddy/releases/download/v2.11.3/caddy_2.11.3_windows_amd64.zip',
      '2.11.2':
          'https://github.com/caddyserver/caddy/releases/download/v2.11.2/caddy_2.11.2_windows_amd64.zip',
      '2.11.1':
          'https://github.com/caddyserver/caddy/releases/download/v2.11.1/caddy_2.11.1_windows_amd64.zip',
      '2.11.0':
          'https://github.com/caddyserver/caddy/releases/download/v2.11.0/caddy_2.11.0_windows_amd64.zip',
    });
  });

  test('Caddy icon is bundled and non-empty', () async {
    final icon = File('assets/images/caddy.png');
    expect(await icon.exists(), isTrue);
    expect(await icon.length(), greaterThan(0));
  });
}
