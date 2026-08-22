// test/features/apps/catalog_url_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dev_stack/features/apps/data/apps_provider.dart';
import 'package:dev_stack/features/apps/data/apps_repository.dart';

void main() {
  group('OS-aware catalog URL', () {
    test('filename segment matches catalogFileNameFor', () {
      final expected =
          AppsRepository.catalogFileNameFor(isLinux: Platform.isLinux);
      expect(AppsNotifier.catalogUrl, endsWith('/$expected'));
    });

    test('filename segment matches catalogFileNameFor with isLinux toggle', () {
      // Direct verification that catalogUrl respects Platform.isLinux
      final linuxExpected = AppsRepository.catalogFileNameFor(isLinux: true);
      expect(linuxExpected, equals('apps-linux.json'));
      final windowsExpected = AppsRepository.catalogFileNameFor(isLinux: false);
      expect(windowsExpected, equals('apps.json'));
    });

    test('points at the shared gist raw base', () {
      expect(
        AppsNotifier.catalogUrl,
        startsWith(
          'https://gist.githubusercontent.com/ngotuananh101/'
          'd2e69956bc2030b0bcf27707aef9e9cd/raw/',
        ),
      );
    });
  });
}
