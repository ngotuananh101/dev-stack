import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dev_stack/features/apps/data/app_installer_service.dart';
import 'package:dev_stack/core/services/log_service.dart';
import 'package:dev_stack/core/config/app_config.dart';
import '../../helpers/test_ref.dart';

void main() {
  late AppInstallerService installer;

  setUp(() {
    AppConfig.initialize(
      baseDir: Directory.systemTemp.createTempSync('ponta_bin_test_').path,
    );
    installer = AppInstallerService(LogService(), testRef());
  });

  test('refuses any path outside the apps directory', () async {
    final logs = <String>[];
    var called = false;
    await installer.setLinuxCapabilityForWebserver(
      '/usr/sbin/httpd',
      logs.add,
      isLinuxOverride: true,
      runProcess: (executable, arguments) async {
        called = true;
        return ProcessResult(1, 0, '', '');
      },
    );
    expect(called, isFalse);
    expect(logs.any((l) => l.contains('outside')), isTrue);
  });
}
