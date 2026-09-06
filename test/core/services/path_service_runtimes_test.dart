import 'package:dev_stack/core/services/path_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PathService runtime shim and PATH management', () {
    test('shimNamesForApp includes bun and bunx for Bun', () {
      final shims = PathService.shimNamesForApp('bun');
      expect(shims, containsAll(['bun', 'bunx']));
    });

    test('shimNamesForApp includes deno for Deno', () {
      final shims = PathService.shimNamesForApp('deno');
      expect(shims, containsAll(['deno']));
    });

    test('shimNamesForApp includes node, npm, npx, corepack for Node.js', () {
      final shims = PathService.shimNamesForApp('nodejs');
      expect(shims, containsAll(['nodejs', 'node', 'npm', 'npx', 'corepack']));
    });
  });
}
