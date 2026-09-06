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

    test('shimNamesForApp includes nodejs and node for Node.js', () {
      final shims = PathService.shimNamesForApp('nodejs');
      expect(shims, containsAll(['nodejs', 'node']));
      // npm, npx, corepack are NOT in shimNamesForApp — they are handled
      // in the dedicated Node.js blocks of addAppToPath/removeAppFromPath.
      expect(shims, isNot(contains('npm')));
      expect(shims, isNot(contains('npx')));
      expect(shims, isNot(contains('corepack')));
    });

    test('shimNamesForApp includes node for node', () {
      final shims = PathService.shimNamesForApp('node');
      expect(shims, containsAll(['node']));
    });

    test('shimNamesForApp includes appId and cliFile basename for php84', () {
      final shims = PathService.shimNamesForApp('php84', 'php.exe');
      expect(shims, containsAll(['php84', 'php']));
    });

    test('shimNamesForApp includes appId and cliFile basename for apache', () {
      final shims = PathService.shimNamesForApp('apache', 'httpd.exe');
      expect(shims, containsAll(['apache', 'httpd']));
    });

    test('shimNamesForApp does not duplicate basename when same as appId', () {
      final shims = PathService.shimNamesForApp('redis', 'redis-cli.exe');
      expect(shims, contains('redis'));
      expect(shims, contains('redis-cli'));
      // No duplicates
      expect(shims.where((s) => s == 'redis').length, 1);
      expect(shims.where((s) => s == 'redis-cli').length, 1);
    });

    test('shimNamesForApp returns [appId] when cliFile is null', () {
      final shims = PathService.shimNamesForApp('php84');
      expect(shims, equals(['php84']));
    });

    test('shimNamesForApp returns [appId] when cliFile is empty', () {
      final shims = PathService.shimNamesForApp('php84', '');
      expect(shims, equals(['php84']));
    });
  });
}
