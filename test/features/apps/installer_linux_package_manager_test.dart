import 'dart:io';

import 'package:dev_stack/core/config/app_config.dart';
import 'package:dev_stack/core/services/log_service.dart';
import 'package:dev_stack/features/apps/data/app_installer_service.dart';
import 'package:dev_stack/features/apps/data/apps_repository.dart';
import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_ref.dart';

void main() {
  test(
    'legacy package-manager requests fail before running commands',
    () async {
      final root = Directory.systemTemp.createTempSync('no_pm_install_');
      addTearDown(() => root.deleteSync(recursive: true));
      AppConfig.initialize(baseDir: root.path);
      final calls = <String>[];
      final app = AppModel(
        appId: 'php84',
        name: 'PHP 8.4',
        categories: ['runtime'],
        groupName: 'php',
        installMethod: 'package_manager',
      );
      await expectLater(
        AppInstallerService(LogService(), testRef()).install(
          app,
          '8.4',
          runProcess: (exe, args) async {
            calls.add(exe);
            return ProcessResult(0, 1, '', 'unexpected');
          },
        ),
        throwsA(isA<UnsupportedError>()),
      );
      expect(calls, isEmpty);
      expect(Directory('${root.path}/apps').existsSync(), isFalse);
    },
  );

  test('old catalog package sentinels do not become installable versions', () {
    final apps = AppsRepository.mergeAppsCatalog([
      {
        'id': 'apache',
        'name': 'Apache',
        'category': 'webserver',
        'install_method': 'package_manager',
        'versions': {'system': 'package_manager'},
        'package_manager_commands': {
          'ubuntu': ['sudo apt-get install -y apache2'],
        },
      },
      {'id': 'php84', 'name': 'PHP 8.4', 'category': 'runtime', 'versions': {}},
    ], {});
    for (final app in apps) {
      expect(app.versions, isEmpty);
      expect(app.versionLinks, isEmpty);
    }
  });
}
