import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Catalog entries for Bun and Deno', () {
    test('apps.json contains Windows definitions for bun and deno', () async {
      final raw = await File('assets/data/apps.json').readAsString();
      final catalog = jsonDecode(raw) as Map<String, dynamic>;
      final apps = (catalog['apps'] as List).cast<Map<String, dynamic>>();

      final bun = apps.firstWhere((a) => a['id'] == 'bun', orElse: () => {});
      expect(bun['name'], equals('Bun'));
      expect(bun['category'], equals('runtime'));
      expect(bun['group_name'], equals('bun'));
      expect(bun['exec_file'], equals('bun.exe'));
      expect(bun['cli_file'], equals('bun.exe'));
      final bunVersions = bun['versions'] as Map<String, dynamic>;
      expect(bunVersions.isNotEmpty, isTrue);
      expect(bunVersions.values.first.toString(), endsWith('bun-windows-x64.zip'));

      final deno = apps.firstWhere((a) => a['id'] == 'deno', orElse: () => {});
      expect(deno['name'], equals('Deno'));
      expect(deno['category'], equals('runtime'));
      expect(deno['group_name'], equals('deno'));
      expect(deno['exec_file'], equals('deno.exe'));
      expect(deno['cli_file'], equals('deno.exe'));
      final denoVersions = deno['versions'] as Map<String, dynamic>;
      expect(denoVersions.isNotEmpty, isTrue);
      expect(denoVersions.values.first.toString(), contains('windows'));
    });

    test('apps-linux.json contains Linux definitions for bun and deno', () async {
      final raw = await File('assets/data/apps-linux.json').readAsString();
      final catalog = jsonDecode(raw) as Map<String, dynamic>;
      final apps = (catalog['apps'] as List).cast<Map<String, dynamic>>();

      final bun = apps.firstWhere((a) => a['id'] == 'bun', orElse: () => {});
      expect(bun['name'], equals('Bun'));
      expect(bun['category'], equals('runtime'));
      expect(bun['group_name'], equals('bun'));
      expect(bun['exec_file'], equals('bun'));
      expect(bun['cli_file'], equals('bun'));
      final bunVersions = bun['versions'] as Map<String, dynamic>;
      expect(bunVersions.isNotEmpty, isTrue);
      expect(bunVersions.values.first.toString(), endsWith('bun-linux-x64.zip'));

      final deno = apps.firstWhere((a) => a['id'] == 'deno', orElse: () => {});
      expect(deno['name'], equals('Deno'));
      expect(deno['category'], equals('runtime'));
      expect(deno['group_name'], equals('deno'));
      expect(deno['exec_file'], equals('deno'));
      expect(deno['cli_file'], equals('deno'));
      final denoVersions = deno['versions'] as Map<String, dynamic>;
      expect(denoVersions.isNotEmpty, isTrue);
      expect(denoVersions.values.first.toString(), contains('linux'));
    });
  });
}
