import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dev_stack/core/config/app_config.dart';
import 'package:path/path.dart' as p;

void main() {
  setUp(() {
    AppConfig.initialize(baseDir: AppConfig.defaultBaseDir);
  });

  group('AppConfig OS paths', () {
    test('resolves defaultBaseDir based on platform', () {
      final defaultDir = AppConfig.defaultBaseDir;
      if (Platform.isLinux) {
        final home = Platform.environment['HOME'] ?? '';
        expect(defaultDir, equals(p.join(home, '.ponta')));
      } else if (Platform.isWindows) {
        expect(defaultDir, equals(r'C:\Ponta'));
      }
    });

    test('subdirectories are constructed using p.join', () {
      AppConfig.initialize(baseDir: p.join('tmp', 'test_ponta'));
      final base = p.join('tmp', 'test_ponta');
      expect(AppConfig.appsDir, equals(p.join(base, 'apps')));
      expect(AppConfig.binDir, equals(p.join(base, 'bin')));
      expect(AppConfig.logsDir, equals(p.join(base, 'logs')));
      expect(AppConfig.webserverRoot, equals(p.join(base, 'www')));
      expect(AppConfig.certsDir, equals(p.join(base, 'certs')));
      expect(AppConfig.vhostsDir, equals(p.join(base, 'vhosts')));
      expect(AppConfig.dataDir, equals(p.join(base, 'data')));
    });

    test('re-initializing with null or empty resets to defaultBaseDir', () {
      AppConfig.initialize(baseDir: p.join('tmp', 'custom'));
      expect(AppConfig.baseDir, equals(p.join('tmp', 'custom')));
      AppConfig.initialize();
      expect(AppConfig.baseDir, equals(AppConfig.defaultBaseDir));
      AppConfig.initialize(baseDir: '');
      expect(AppConfig.baseDir, equals(AppConfig.defaultBaseDir));
    });

    test('updateBaseDirEnvVar calls runner with environment map on Windows', () async {
      final calls = <({String exe, List<String> args, Map<String, String>? env})>[];
      await updateBaseDirEnvVar(
        r'C:\Custom\Ponta',
        isWindows: true,
        runProcess: (exe, args, {environment}) async {
          calls.add((exe: exe, args: args, env: environment));
          return ProcessResult(1234, 0, '', '');
        },
      );

      expect(calls.length, equals(1));
      expect(calls[0].exe, equals('powershell'));
      expect(calls[0].env?['DEVSTACK_ENVVAR'], equals('DEVSTACK_BASE_DIR'));
      expect(calls[0].env?['DEVSTACK_SETVALUE'], equals(r'C:\Custom\Ponta'));
    });
  });
}
