import 'dart:async';
import 'dart:io';

import 'package:dev_stack/core/config/app_config.dart';
import 'package:dev_stack/core/services/log_service.dart';
import 'package:dev_stack/features/apps/data/app_installer_service.dart';
import 'package:dev_stack/features/apps/data/app_service_manager.dart';
import 'package:dev_stack/features/apps/data/apps_provider.dart';
import 'package:dev_stack/features/apps/data/apps_repository.dart';
import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:dev_stack/shared/providers/error_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

class _FakeRepository implements AppsRepository {
  final List<AppModel> apps;
  final List<AppModel> saved = [];

  _FakeRepository(this.apps);

  @override
  Future<List<AppModel>> getAll() async => apps;

  @override
  Future<void> save(AppModel app) async => saved.add(app);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Replaces only the host process operations. Like a real webserver, the fake
/// process reads its integration file when it starts or restarts, not on write.
class _ConfigReadingManager extends AppServiceManager {
  _ConfigReadingManager(super.logger, this.configFile);

  final File configFile;
  bool running = false;
  int starts = 0;
  int restarts = 0;
  String? loadedConfig;

  @override
  bool isRunning(String appId) => running;

  @override
  Future<void> start(AppModel app, {VoidCallback? onStatusChange}) async {
    if (running) return;
    starts++;
    running = true;
    loadedConfig = configFile.existsSync()
        ? configFile.readAsStringSync()
        : null;
  }

  @override
  Future<void> restart(AppModel app, {VoidCallback? onStatusChange}) async {
    restarts++;
    running = false;
    await start(app, onStatusChange: onStatusChange);
  }
}

class _RestartFailureManager extends AppServiceManager {
  _RestartFailureManager(super.logger, this.configFile);

  final File configFile;
  bool running = false;
  bool restartFailed = false;

  @override
  bool isRunning(String appId) => running;

  @override
  Future<void> start(AppModel app, {VoidCallback? onStatusChange}) async {
    if (running) return;
    if (restartFailed) {
      throw Exception('simulated webserver start failure after restart');
    }
    running = true;
  }

  @override
  Future<void> restart(AppModel app, {VoidCallback? onStatusChange}) async {
    running = false;
    restartFailed = true;
    await start(app, onStatusChange: onStatusChange);
  }
}

class _StartFailureManager extends AppServiceManager {
  _StartFailureManager.withError(super.logger, this.startError);

  final Object startError;

  @override
  bool isRunning(String appId) => false;

  @override
  Future<void> start(AppModel app, {VoidCallback? onStatusChange}) async {
    throw startError;
  }
}

class _CompleterManager extends AppServiceManager {
  _CompleterManager(super.logger, this.configFile);

  final File configFile;
  bool running = false;
  final Completer<void> startGate = Completer<void>();
  final Completer<void> started = Completer<void>();
  String? loadedConfig;

  @override
  bool isRunning(String appId) => running;

  @override
  Future<void> start(AppModel app, {VoidCallback? onStatusChange}) async {
    if (running) return;
    await startGate.future;
    running = true;
    loadedConfig = configFile.existsSync()
        ? configFile.readAsStringSync()
        : null;
    if (!started.isCompleted) started.complete();
  }
}

void main() {
  late Directory root;
  late LogService logger;
  late String previousBaseDir;

  setUp(() {
    root = Directory.systemTemp.createTempSync('webserver_config_sync_');
    previousBaseDir = AppConfig.baseDir;
    AppConfig.initialize(baseDir: root.path);
    logger = LogService(logDir: p.join(root.path, 'logs'));
    addTearDown(() async {
      // Drain fire-and-forget installer logs before deleting the test directory.
      await logger.info('Test finished');
      AppConfig.initialize(baseDir: previousBaseDir);
      root.deleteSync(recursive: true);
    });
  });

  for (final server in ['nginx', 'caddy', 'apache']) {
    group(server, () {
      late AppModel webserver;
      late AppModel pma;
      late AppModel php;
      late Directory phpDir;
      late AppInstallerService installer;
      late _FakeRepository repository;
      late _ConfigReadingManager manager;
      late ProviderContainer container;

      setUp(() async {
        webserver = AppModel(
          appId: server,
          name: server,
          categories: const ['webserver'],
          groupName: 'webserver',
          isInstalled: true,
          location: p.join(root.path, server),
        );
        pma = AppModel(
          appId: 'phpMyAdmin',
          name: 'phpMyAdmin',
          categories: const ['tool'],
          isInstalled: true,
          location: p.join(root.path, 'pma-new'),
        );
        phpDir = Directory(p.join(root.path, 'php', 'php-8.3'))
          ..createSync(recursive: true);
        php = AppModel(
          appId: 'php-8.3',
          name: 'PHP 8.3',
          categories: const ['language'],
          groupName: 'php',
          isInstalled: true,
          isDefault: true,
          location: phpDir.path,
        );
        final configFile = File(
          server == 'apache'
              ? p.join(AppConfig.vhostsDir, server, 'phpmyadmin.conf')
              : p.join(
                  AppConfig.vhostsDir,
                  server,
                  'integrations',
                  'phpmyadmin.conf',
                ),
        );
        manager = _ConfigReadingManager(logger, configFile);
        repository = _FakeRepository([webserver, pma, php]);
        container = ProviderContainer.test(
          overrides: [
            appsRepositoryProvider.overrideWith((ref) async => repository),
            appServiceManagerProvider.overrideWithValue(manager),
            appInstallerServiceProvider.overrideWith(
              (ref) => AppInstallerService(logger, ref),
            ),
          ],
        );
        installer = container.read(appInstallerServiceProvider);
        await container.read(appsProvider.future);
      });

      test(
        'a stopped webserver loads synced config on its first start',
        () async {
          await container.read(appsProvider.notifier).startService(webserver);

          expect(manager.loadedConfig, contains('pma-new'));
          expect(manager.starts, 1);
          expect(manager.restarts, 0);
          expect(webserver.autoStartService, isTrue);
          expect(repository.saved, [webserver]);
        },
      );

      test('an already running webserver loads changed config', () async {
        pma.location = p.join(root.path, 'pma-old');
        await installer.syncInterAppConfigs(webserver, repository.apps);
        await manager.start(webserver);
        expect(manager.loadedConfig, contains('pma-old'));
        pma.location = p.join(root.path, 'pma-new');

        await container.read(appsProvider.notifier).startService(webserver);

        expect(manager.loadedConfig, contains('pma-new'));
        expect(manager.restarts, 1);
      });

      test('unchanged config does not restart a running webserver', () async {
        await installer.syncInterAppConfigs(webserver, repository.apps);
        await manager.start(webserver);
        final loadedConfig = manager.loadedConfig;

        await container.read(appsProvider.notifier).startService(webserver);

        expect(manager.loadedConfig, loadedConfig);
        expect(manager.restarts, 0);
      });

      test('no installed phpMyAdmin means no restart', () async {
        pma.isInstalled = false;
        await manager.start(webserver);

        await container.read(appsProvider.notifier).startService(webserver);

        expect(manager.configFile.existsSync(), isFalse);
        expect(manager.restarts, 0);
      });

      test(
        'webserver restart failure surfaces app error and preserves autoStart',
        () async {
          final restartManager = _RestartFailureManager(logger, manager.configFile);
          final restartContainer = ProviderContainer.test(
            overrides: [
              appsRepositoryProvider.overrideWith((ref) async => repository),
              appServiceManagerProvider.overrideWithValue(restartManager),
              appInstallerServiceProvider.overrideWith(
                (ref) => AppInstallerService(logger, ref),
              ),
            ],
          );
          addTearDown(restartContainer.dispose);
          await restartContainer.read(appsProvider.future);

          pma.location = p.join(root.path, 'pma-old');
          await installer.syncInterAppConfigs(webserver, repository.apps);
          restartManager.running = true;
          pma.location = p.join(root.path, 'pma-new');
          webserver.autoStartService = true;
          final savedBefore = repository.saved.length;

          await restartContainer
              .read(appsProvider.notifier)
              .startService(webserver);

          expect(restartManager.restartFailed, isTrue);
          expect(webserver.autoStartService, isTrue);
          expect(repository.saved.length, savedBefore);
          final appError = restartContainer.read(appErrorProvider);
          expect(appError, isNotNull);
          expect(appError, contains('simulated webserver start failure'));
        },
      );

      if (server == 'nginx') {
        test(
          'invalid UTF8 target keeps legacy nginx phpMyAdmin config intact',
          () async {
            final legacyConf = File(
              p.join(AppConfig.vhostsDir, 'nginx', 'phpmyadmin.conf'),
            );
            legacyConf.parent.createSync(recursive: true);
            legacyConf.writeAsStringSync('legacy-pma-config');

            final integrationsTarget = File(
              p.join(
                AppConfig.vhostsDir,
                'nginx',
                'integrations',
                'phpmyadmin.conf',
              ),
            );
            integrationsTarget.parent.createSync(recursive: true);
            integrationsTarget.writeAsBytesSync([0x80, 0xff, 0xfe, 0x41]);

            final changed = await installer.syncInterAppConfigs(
              webserver,
              repository.apps,
            );

            expect(changed, isFalse);
            expect(legacyConf.existsSync(), isTrue);
            expect(legacyConf.readAsStringSync(), 'legacy-pma-config');
          },
        );

        test(
          'directory target keeps legacy nginx phpMyAdmin config intact',
          () async {
            final legacyConf = File(
              p.join(AppConfig.vhostsDir, 'nginx', 'phpmyadmin.conf'),
            );
            legacyConf.parent.createSync(recursive: true);
            legacyConf.writeAsStringSync('legacy-pma-config');

            final integrationsTarget = Directory(
              p.join(
                AppConfig.vhostsDir,
                'nginx',
                'integrations',
                'phpmyadmin.conf',
              ),
            );
            integrationsTarget.createSync(recursive: true);

            final changed = await installer.syncInterAppConfigs(
              webserver,
              repository.apps,
            );

            expect(changed, isFalse);
            expect(legacyConf.existsSync(), isTrue);
            expect(legacyConf.readAsStringSync(), 'legacy-pma-config');
          },
        );

        test(
          'legacy nginx config is removed after successful migration',
          () async {
            final legacyConf = File(
              p.join(AppConfig.vhostsDir, 'nginx', 'phpmyadmin.conf'),
            );
            legacyConf.parent.createSync(recursive: true);
            legacyConf.writeAsStringSync('legacy-pma-config');

            final changed = await installer.syncInterAppConfigs(
              webserver,
              repository.apps,
            );

            expect(changed, isTrue);
            expect(legacyConf.existsSync(), isFalse);
            final target = File(
              p.join(
                AppConfig.vhostsDir,
                'nginx',
                'integrations',
                'phpmyadmin.conf',
              ),
            );
            expect(target.existsSync(), isTrue);
            expect(target.readAsStringSync(), contains('pma-new'));
          },
        );

        test(
          'already-correct nginx integration still removes legacy config',
          () async {
            await installer.syncInterAppConfigs(webserver, repository.apps);
            final target = File(
              p.join(
                AppConfig.vhostsDir,
                'nginx',
                'integrations',
                'phpmyadmin.conf',
              ),
            );
            final existing = target.readAsStringSync();
            final legacyConf = File(
              p.join(AppConfig.vhostsDir, 'nginx', 'phpmyadmin.conf'),
            );
            legacyConf.writeAsStringSync('legacy-pma-config');

            final changed = await installer.syncInterAppConfigs(
              webserver,
              repository.apps,
            );

            expect(changed, isTrue);
            expect(legacyConf.existsSync(), isFalse);
            expect(target.readAsStringSync(), existing);
          },
        );
      }

      test(
        'invalid default PHP ini does not block stopped webserver start',
        () async {
          final phpIni = File(p.join(phpDir.path, 'php.ini'));
          final invalidBytes = [0x80, 0xff, 0xfe, 0x41, 0x42];
          phpIni.writeAsBytesSync(invalidBytes);

          await container.read(appsProvider.notifier).startService(webserver);

          expect(manager.running, isTrue);
          expect(manager.starts, 1);
          expect(manager.loadedConfig, contains('pma-new'));
          expect(webserver.autoStartService, isTrue);
          expect(repository.saved, contains(webserver));
          expect(phpIni.readAsBytesSync(), invalidBytes);

          await logger.info('drain');
          final logDir = Directory(p.join(root.path, 'logs'));
          final logText = logDir
              .listSync()
              .whereType<File>()
              .map((f) => f.readAsStringSync())
              .join('\n');
          expect(logText, contains('optional PHP extension preparation'));
        },
      );

      test(
        'optional extension prep failure does not swallow manager.start failure',
        () async {
          final phpIni = File(p.join(phpDir.path, 'php.ini'));
          phpIni.writeAsBytesSync([0x80, 0xff, 0xfe, 0x41, 0x42]);
          final startError = Exception('simulated manager.start failure');
          final failingManager = _StartFailureManager.withError(
            logger,
            startError,
          );
          final failingContainer = ProviderContainer.test(
            overrides: [
              appsRepositoryProvider.overrideWith((ref) async => repository),
              appServiceManagerProvider.overrideWithValue(failingManager),
              appInstallerServiceProvider.overrideWith(
                (ref) => AppInstallerService(logger, ref),
              ),
            ],
          );
          addTearDown(failingContainer.dispose);
          await failingContainer.read(appsProvider.future);

          await failingContainer
              .read(appsProvider.notifier)
              .startService(webserver);

          expect(webserver.autoStartService, isFalse);
          expect(repository.saved, isEmpty);
          final appError = failingContainer.read(appErrorProvider);
          expect(appError, isNotNull);
          expect(appError, contains('simulated manager.start failure'));
        },
      );
    });
  }

  test(
    'autoStartService webserver loads synced config at startup',
    () async {
      final server = 'nginx';
      final webserver = AppModel(
        appId: server,
        name: server,
        categories: const ['webserver'],
        groupName: 'webserver',
        isInstalled: true,
        autoStartService: true,
        location: p.join(root.path, server),
      );
      final pma = AppModel(
        appId: 'phpMyAdmin',
        name: 'phpMyAdmin',
        categories: const ['tool'],
        isInstalled: true,
        location: p.join(root.path, 'pma-new'),
      );
      final phpDir = Directory(p.join(root.path, 'php', 'php-8.3-char'))
        ..createSync(recursive: true);
      final php = AppModel(
        appId: 'php-8.3',
        name: 'PHP 8.3',
        categories: const ['language'],
        groupName: 'php',
        isInstalled: true,
        isDefault: true,
        location: phpDir.path,
      );
      final configFile = File(
        p.join(AppConfig.vhostsDir, server, 'integrations', 'phpmyadmin.conf'),
      );
      final manager = _CompleterManager(logger, configFile);
      final repository = _FakeRepository([webserver, pma, php]);
      final container = ProviderContainer.test(
        overrides: [
          appsRepositoryProvider.overrideWith((ref) async => repository),
          appServiceManagerProvider.overrideWithValue(manager),
          appInstallerServiceProvider.overrideWith(
            (ref) => AppInstallerService(logger, ref),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(appsProvider.future);
      manager.startGate.complete();
      await manager.started.future;
      await pumpEventQueue(times: 20);

      expect(manager.loadedConfig, contains('pma-new'));
      expect(manager.running, isTrue);
    },
  );
}
