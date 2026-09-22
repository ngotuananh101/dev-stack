import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:dev_stack/features/apps/data/app_installer_service.dart';
import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:dev_stack/core/services/log_service.dart';
import 'package:dev_stack/core/config/app_config.dart';
import '../../helpers/test_ref.dart';


void main() {
  late AppInstallerService installer;
  late Directory tempDir;

  setUp(() {
    AppConfig.initialize(baseDir: Directory.systemTemp.createTempSync('ponta_bin_test_').path);
    installer = AppInstallerService(LogService(), testRef());
    tempDir = Directory.systemTemp.createTempSync('ponta_bin_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('findInstalledBinary', () {
    test('resolves via which command when available', () async {
      final binaryPath = await installer.findInstalledBinary(
        'postgres',
        runProcess: (exec, args) async {
          if (exec == 'which' && args.first == 'postgres') {
            return ProcessResult(1, 0, '/usr/lib/postgresql/16/bin/postgres\n', '');
          }
          return ProcessResult(2, 1, '', 'not found');
        },
      );
      expect(binaryPath, equals('/usr/lib/postgresql/16/bin/postgres'));
    });

    test('falls back to candidate search if which fails', () async {
      final fakeBin = File(p.join(tempDir.path, 'apache2'))..createSync();
      final binaryPath = await installer.findInstalledBinary(
        'apache2',
        candidates: [fakeBin.path],
        runProcess: (exec, args) async => ProcessResult(1, 1, '', 'not found'),
      );
      expect(binaryPath, equals(fakeBin.path));
    });

    test('supports wildcard/glob-like candidate expansion for postgresql', () async {
      final pgDir = Directory(p.join(tempDir.path, 'usr', 'lib', 'postgresql', '16', 'bin'))..createSync(recursive: true);
      final pgBin = File(p.join(pgDir.path, 'postgres'))..createSync();

      final binaryPath = await installer.findInstalledBinary(
        'postgres',
        searchDirectories: [p.join(tempDir.path, 'usr', 'lib', 'postgresql')],
        runProcess: (exec, args) async => ProcessResult(1, 1, '', 'not found'),
      );
      expect(binaryPath, equals(pgBin.path));
    });
  });

  group('setLinuxCapabilityForWebserver with system binaries', () {
    test('allows setting capability on system webserver binaries (/usr/sbin/apache2)', () async {
      final logMessages = <String>[];
      final fakeSystemApache = File(p.join(tempDir.path, 'apache2'))..createSync();

      var setcapCalled = false;
      await installer.setLinuxCapabilityForWebserver(
        fakeSystemApache.path,
        logMessages.add,
        isLinuxOverride: true,
        allowSystemBinaries: true,
        runProcess: (executable, arguments) async {
          if (executable == 'sudo' && arguments.contains('cap_net_bind_service=+ep')) {
            setcapCalled = true;
            return ProcessResult(1, 0, '', '');
          }
          return ProcessResult(2, 1, '', 'failed');
        },
      );

      expect(setcapCalled, isTrue);
    });
  });

  group('resolveExecNames', () {
    test('resolves apache to apache2 and httpd', () {
      final app = AppModel(
        appId: 'apache',
        name: 'Apache',
        groupName: 'webserver',
        categories: ['webserver'],
        execFile: 'apache2',
      );
      expect(AppInstallerService.resolveExecNames(app), equals(['apache2', 'httpd']));
    });

    test('resolves php83 to php-fpm8.3, php83-php-fpm, and php-fpm', () {
      final app = AppModel(
        appId: 'php83',
        name: 'PHP 8.3',
        groupName: 'php',
        categories: ['runtime'],
        execFile: 'php-fpm8.3',
      );
      expect(
        AppInstallerService.resolveExecNames(app),
        equals(['php-fpm8.3', 'php83-php-fpm', 'php-fpm']),
      );
    });

    test('resolves unversioned php to php-fpm', () {
      final app = AppModel(
        appId: 'php',
        name: 'PHP',
        groupName: 'php',
        categories: ['runtime'],
      );
      expect(
        AppInstallerService.resolveExecNames(app),
        equals(['php-fpm']),
      );
    });
  });
}
