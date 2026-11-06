import 'dart:io';

import 'package:dev_stack/core/config/app_config.dart';
import 'package:dev_stack/core/services/log_service.dart';
import 'package:dev_stack/features/apps/data/app_installer_service.dart';
import 'package:dev_stack/features/apps/data/app_service_manager.dart';
import 'package:dev_stack/features/apps/data/apps_provider.dart';
import 'package:dev_stack/features/apps/data/apps_repository.dart';
import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../helpers/test_ref.dart';

class _Repository implements AppsRepository {
  final List<AppModel> apps;
  _Repository(this.apps);

  @override
  Future<List<AppModel>> getAll() async => apps;

  @override
  Future<void> delete(String appId) async =>
      apps.removeWhere((app) => app.appId == appId);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Keep real termination logic, but model processes at the external runner boundary.
class _Services extends AppServiceManager {
  _Services(Future<List<String>> Function(String, List<String>) runProcess)
    : super(LogService(), runProcess: runProcess);

  @override
  void syncAppState(AppModel app) {}

  @override
  bool isRunning(String appId) => false;
}

void main() {
  late Directory root;
  late ProviderContainer container;
  late _Repository repository;
  late AppModel app;
  late Map<int, String> processes;
  late List<List<String>> commands;

  setUp(() {
    root = Directory.systemTemp.createTempSync('uninstall_compat_');
    AppConfig.initialize(baseDir: root.path);
    app = AppModel(
      appId: 'postgresql',
      name: 'PostgreSQL',
      categories: ['database'],
      isInstalled: true,
      installedVersion: '16.0',
      status: 'installed',
    );
    repository = _Repository([app]);
    processes = {};
    commands = [];
    final services = _Services((exe, args) async {
      commands.add([exe, ...args]);
      if (exe == 'pkill') {
        processes.removeWhere((pid, name) => name == args.last);
      } else if (exe == 'kill') {
        processes.remove(int.parse(args.last).abs());
      }
      return [];
    });
    container = ProviderContainer.test(
      overrides: [
        appsRepositoryProvider.overrideWith((ref) async => repository),
        appInstallerServiceProvider.overrideWithValue(
          AppInstallerService(LogService(), testRef()),
        ),
        appServiceManagerProvider.overrideWithValue(services),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    AppConfig.initialize(baseDir: AppConfig.defaultBaseDir);
    root.deleteSync(recursive: true);
  });

  for (final system in [false, true]) {
    for (final pid in [null, 1234]) {
      test(
        'uninstall ${system ? 'system' : 'portable'} PHP with PID $pid preserves other runtimes',
        () async {
          app = AppModel(
            appId: 'php84',
            name: 'PHP 8.4',
            categories: ['runtime'],
            isInstalled: true,
            execFile: 'php-fpm',
            cliFile: 'php',
          )..servicePid = pid;
          repository.apps
            ..clear()
            ..add(app);
          final install = Directory(p.join(root.path, 'apps/php84/8.4.27'))
            ..createSync(recursive: true);
          app.location = system
              ? AppInstallerService.systemPackageMarker
              : install.path;
          // Another FPM master and CLI share the catalog's unversioned names.
          processes.addAll({2345: 'php-fpm', 3456: 'php'});
          if (pid != null) processes[pid] = 'php-fpm';
          await container.read(appsProvider.future);
          await container.read(appsProvider.notifier).uninstall(app);
          expect(repository.apps, isEmpty);
          expect(processes, {2345: 'php-fpm', 3456: 'php'});
          expect(
            commands,
            pid == null
                ? isEmpty
                : [
                    ['kill', '-9', '--', '-1234'],
                  ],
          );
        },
      );
    }
  }

  test(
    'uninstall forgets a legacy system record without deleting its data',
    () async {
      app.location = AppInstallerService.systemPackageMarker;
      final data = Directory(p.join(AppConfig.dataDir, 'postgresql-16.0'))
        ..createSync(recursive: true);
      final marker = File(p.join(data.path, 'PG_VERSION'))
        ..writeAsStringSync('16\n');
      await container.read(appsProvider.future);
      await container.read(appsProvider.notifier).uninstall(app);
      expect(repository.apps, isEmpty);
      expect(app.isInstalled, isFalse);
      expect(marker.readAsStringSync(), '16\n');
    },
  );

  test(
    'uninstall removes a managed directory even with stale catalog install metadata',
    () async {
      final install = Directory(p.join(root.path, 'apps/postgresql/16.0'))
        ..createSync(recursive: true);
      app.location = install.path;
      app.installMethod = 'package_manager';
      await container.read(appsProvider.future);
      await container.read(appsProvider.notifier).uninstall(app);
      expect(repository.apps, isEmpty);
      expect(app.isInstalled, isFalse);
      expect(install.existsSync(), isFalse);
    },
  );
}
