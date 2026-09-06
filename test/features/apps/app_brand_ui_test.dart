import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Helper extracting icon and color logic for testability
String getAppIconName(String appId) {
  final id = appId.toLowerCase();
  if (id.contains('bun')) return 'bun';
  if (id.contains('deno')) return 'deno';
  if (id.contains('nodejs')) return 'nodejs';
  return id;
}

Color getAppIconColor(String appId) {
  final id = appId.toLowerCase();
  if (id.contains('bun')) return const Color(0xFFE5A83B);
  if (id.contains('deno')) return const Color(0xFF70FFAF);
  if (id.contains('node')) return const Color(0xFF68A063);
  return const Color(0xFF000000);
}

void main() {
  group('App Brand UI resolution for Bun and Deno', () {
    test('resolves bun icon and brand color', () {
      expect(getAppIconName('bun'), equals('bun'));
      expect(getAppIconColor('bun'), equals(const Color(0xFFE5A83B)));
    });

    test('resolves deno icon and brand color', () {
      expect(getAppIconName('deno'), equals('deno'));
      expect(getAppIconColor('deno'), equals(const Color(0xFF70FFAF)));
    });
  });
}
