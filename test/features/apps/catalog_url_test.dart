// test/features/apps/catalog_url_test.dart
import 'dart:io';

import 'package:dev_stack/features/apps/data/apps_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OS-aware catalog URL', () {
    test('the current OS uses its remote catalog', () {
      final expected = Platform.isLinux ? 'apps-linux-v2.json' : 'apps.json';
      expect(Apps.catalogUrl, endsWith('/$expected'));
    });

    test('Linux uses the versioned feed while Windows keeps its filename', () {
      expect(
        Apps.catalogUrlFor(isLinux: true),
        endsWith('/apps-linux-v2.json'),
      );
      expect(Apps.catalogUrlFor(isLinux: false), endsWith('/apps.json'));
    });

    test('points at the shared gist raw base', () {
      expect(
        Apps.catalogUrl,
        startsWith(
          'https://gist.githubusercontent.com/ngotuananh101/'
          'd2e69956bc2030b0bcf27707aef9e9cd/raw/',
        ),
      );
    });
  });
}
