import 'package:dev_stack/core/services/path_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PathService.shimTargetFor', () {
    test('Go shims each point at their own binary', () {
      const goBin = '/opt/ponta/apps/go/1.27.3/bin/go';
      expect(PathService.shimTargetFor('go', 'go', goBin), goBin);
      expect(
        PathService.shimTargetFor('go', 'gofmt', goBin),
        '/opt/ponta/apps/go/1.27.3/bin/gofmt',
        reason: 'gofmt must not be routed through the go driver',
      );
    });

    test('Flutter shims each point at their own launcher', () {
      const dartBin = '/opt/ponta/apps/flutter/3.47.9/bin/dart';
      expect(PathService.shimTargetFor('flutter', 'dart', dartBin), dartBin);
      expect(
        PathService.shimTargetFor('flutter', 'flutter', dartBin),
        '/opt/ponta/apps/flutter/3.47.9/bin/flutter',
        reason: 'a `flutter` shim pointing at dart would run the wrong tool',
      );
    });

    test('Flutter on Windows uses the batch launchers', () {
      const dartBat = r'C:\Ponta\apps\flutter\3.47.9\bin\dart.bat';
      expect(
        PathService.shimTargetFor('flutter', 'dart', dartBat, isWindows: true),
        dartBat,
      );
      expect(
        PathService.shimTargetFor(
          'flutter',
          'flutter',
          dartBat,
          isWindows: true,
        ),
        r'C:\Ponta\apps\flutter\3.47.9\bin\flutter.bat',
      );
    });

    test('every other app keeps the single CLI target', () {
      expect(
        PathService.shimTargetFor('bun', 'bunx', '/opt/bun/bun'),
        '/opt/bun/bun',
      );
      expect(
        PathService.shimTargetFor('php84', 'php', '/opt/php/bin/php'),
        '/opt/php/bin/php',
      );
    });
  });
}
