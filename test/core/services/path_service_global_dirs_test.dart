import 'package:dev_stack/core/services/path_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PathService.globalPackageDirForApp', () {
    test('returns %APPDATA%\\npm for nodejs on Windows', () {
      final dir = PathService.globalPackageDirForApp(
        'nodejs',
        isWindows: true,
        environment: {'APPDATA': r'C:\Users\Alice\AppData\Roaming'},
      );
      expect(dir, equals(r'C:\Users\Alice\AppData\Roaming\npm'));
    });

    test('returns ~/.npm-global/bin for nodejs on Linux', () {
      final dir = PathService.globalPackageDirForApp(
        'nodejs',
        isWindows: false,
        environment: {'HOME': '/home/alice'},
      );
      expect(dir, equals('/home/alice/.npm-global/bin'));
    });

    test('returns %USERPROFILE%\.bun\bin for bun on Windows', () {
      final dir = PathService.globalPackageDirForApp(
        'bun',
        isWindows: true,
        environment: {'USERPROFILE': r'C:\Users\Alice'},
      );
      expect(dir, equals(r'C:\Users\Alice\.bun\bin'));
    });

    test('returns ~/.bun/bin for bun on Linux', () {
      final dir = PathService.globalPackageDirForApp(
        'bun',
        isWindows: false,
        environment: {'HOME': '/home/alice'},
      );
      expect(dir, equals('/home/alice/.bun/bin'));
    });

    test('returns %USERPROFILE%\.deno\bin for deno on Windows', () {
      final dir = PathService.globalPackageDirForApp(
        'deno',
        isWindows: true,
        environment: {'USERPROFILE': r'C:\Users\Alice'},
      );
      expect(dir, equals(r'C:\Users\Alice\.deno\bin'));
    });

    test('returns ~/.deno/bin for deno on Linux', () {
      final dir = PathService.globalPackageDirForApp(
        'deno',
        isWindows: false,
        environment: {'HOME': '/home/alice'},
      );
      expect(dir, equals('/home/alice/.deno/bin'));
    });

    test('returns null for non-JS apps', () {
      expect(PathService.globalPackageDirForApp('mysql'), isNull);
      expect(PathService.globalPackageDirForApp('nginx'), isNull);
      expect(PathService.globalPackageDirForApp('php84'), isNull);
    });
  });
}
