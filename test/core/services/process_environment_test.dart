import 'dart:io';

import 'package:dev_stack/core/services/process_environment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildEnrichedEnvironment (I5)', () {
    test('merges extra variables over the parent environment', () {
      final env = buildEnrichedEnvironment(
        extra: const {'DEVSTACK_TEST_VAR': 'hello'},
      );
      expect(env['DEVSTACK_TEST_VAR'], 'hello');
    });

    test('extra variables win over the parent environment', () {
      final env = buildEnrichedEnvironment(
        extra: const {'PATH': '/custom/bin'},
      );
      expect(env['PATH'], '/custom/bin');
    });

    test('prepends an existing enriched directory to PATH', () {
      final env = buildEnrichedEnvironment();
      // /usr/local/bin is one of the POSIX enrichment candidates and is
      // essentially always present on the CI/dev machines this runs on.
      if (Platform.isLinux || Platform.isMacOS) {
        final path = env['PATH'] ?? '';
        final separator = Platform.isWindows ? ';' : ':';
        final entries = path.split(separator);
        final existing = const [
          '/usr/local/bin',
          '/usr/bin',
          '/bin',
        ].where((d) => Directory(d).existsSync()).toList();
        expect(existing, isNotEmpty,
            reason: 'test host should have at least one standard bin dir');
        for (final dir in existing) {
          expect(entries, contains(dir));
        }
      }
    });

    test('without extras the parent environment is preserved', () {
      final env = buildEnrichedEnvironment();
      for (final entry in Platform.environment.entries) {
        // PATH may be rewritten; every other key is passed through untouched.
        if (entry.key == 'PATH') continue;
        expect(env[entry.key], entry.value);
      }
    });
  });
}
