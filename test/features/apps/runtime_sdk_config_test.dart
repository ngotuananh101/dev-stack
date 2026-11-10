import 'package:flutter_test/flutter_test.dart';
import 'package:dev_stack/features/apps/data/runtime_sdk_config.dart';

void main() {
  group('RuntimeSdkConfig.forApp', () {
    test('Go needs GOROOT and a bin/ directory', () {
      final config = RuntimeSdkConfig.forApp('go', '/opt/ponta/apps/go/1.27.3');

      expect(config, isNotNull);
      expect(config!.envVars, {
        'GOROOT': '/opt/ponta/apps/go/1.27.3',
      });
      expect(config.pathDirs, ['/opt/ponta/apps/go/1.27.3/bin']);
      expect(config.shims, ['go', 'gofmt']);
    });

    test('Flutter needs the SDK root on PATH and its own shims', () {
      final config = RuntimeSdkConfig.forApp(
        'flutter',
        r'C:\Ponta\apps\flutter\3.47.9',
      );

      expect(config, isNotNull);
      expect(config!.envVars, isEmpty);
      expect(config.pathDirs, [r'C:\Ponta\apps\flutter\3.47.9\bin']);
      expect(config.shims, containsAll(['flutter', 'dart']));
    });

    test('every other runtime is left alone', () {
      expect(RuntimeSdkConfig.forApp('nodejs', '/opt/x'), isNull);
      expect(RuntimeSdkConfig.forApp('php84', '/opt/x'), isNull);
    });
  });

  group('RuntimeSdkConfig.warmupCommand', () {
    test('runs the Flutter launcher in place on Linux', () {
      const launcher = '/opt/ponta/apps/flutter/3.47.9/bin/flutter';
      final cmd = RuntimeSdkConfig.warmupCommand(
        'flutter',
        launcher,
        isWindows: false,
      );

      expect(cmd, isNotNull);
      expect(cmd!.executable, launcher);
      expect(cmd.arguments, ['--version']);
      expect(cmd.runInShell, isFalse);
    });

    test('runs the Windows batch launcher through the shell', () {
      final cmd = RuntimeSdkConfig.warmupCommand(
        'flutter',
        r'C:\Ponta\apps\flutter\3.47.9\bin\flutter.bat',
        isWindows: true,
      );

      expect(
        cmd!.runInShell,
        isTrue,
        reason: 'Process.run cannot start a .bat without cmd',
      );
    });

    test('Go needs no bootstrap step', () {
      expect(
        RuntimeSdkConfig.warmupCommand(
          'go',
          '/opt/ponta/apps/go/1.27.3/bin/go',
          isWindows: false,
        ),
        isNull,
      );
    });
  });
}
