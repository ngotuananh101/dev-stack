import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:path/path.dart' as p;
import '../../../core/config/app_config.dart';
import '../../../core/database/isar_provider.dart';
import '../domain/app_model.dart';
import 'apps_repository.dart';
import 'app_installer_service.dart';
import 'app_service_manager.dart';
import '../../../core/services/path_service.dart';

import '../../../shared/providers/error_provider.dart';

import 'dart:io';
import 'rustfs_settings_provider.dart';
import 'meilisearch_settings_provider.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:dev_stack/core/services/log_service.dart';

part 'apps_provider.g.dart';

@riverpod
Future<AppsRepository> appsRepository(Ref ref) async {
  final isar = await ref.watch(isarProvider.future);
  return AppsRepository(isar);
}

@riverpod
class AppsNotifier extends _$AppsNotifier {
  @override
  Future<List<AppModel>> build() async {
    final repository = await ref.watch(appsRepositoryProvider.future);

    final apps = await repository.getAll();
    final serviceManager = ref.read(appServiceManagerProvider);
    for (final app in apps) {
      serviceManager.syncAppState(app);
    }

    // Auto start services after initial load
    Future.microtask(() {
      for (final app in apps) {
        if (app.isInstalled && app.isService && app.autoStartService) {
          AppLogger.info('Auto-starting service: ${app.name}');
          startService(app);
        }
      }
    });

    return apps;
  }

  Future<void> refresh() async {
    final repository = await ref.read(appsRepositoryProvider.future);
    final list = await repository.getAll();
    final serviceManager = ref.read(appServiceManagerProvider);
    for (final app in list) {
      serviceManager.syncAppState(app);
    }
    state = AsyncValue.data(list);
  }

  DateTime? _lastUpdate;

  /// Updates the state without setting it to loading, used for progress updates
  void notifyUpdate({bool force = false}) {
    final now = DateTime.now();
    if (!force &&
        _lastUpdate != null &&
        now.difference(_lastUpdate!).inMilliseconds < 100) {
      return; // Throttle to 10fps for log/progress updates
    }
    _lastUpdate = now;

    final currentData = state.valueOrNull;
    if (currentData != null) {
      state = AsyncValue.data([...currentData]);
    }
  }

  Future<void> toggleInstallation(AppModel app) async {
    final repository = await ref.read(appsRepositoryProvider.future);

    // Guard against concurrent installation
    if (app.status == 'installing') return;

    if (!app.isInstalled) {
      try {
        final version = app.selectedVersion ?? 'latest';
        final installer = ref.read(appInstallerServiceProvider);

        // Rules for phpMyAdmin
        if (app.appId == 'phpMyAdmin') {
          final allApps = state.valueOrNull ?? [];
          final hasWebServer = allApps.any(
            (a) => a.isInstalled && a.categories.contains('webserver'),
          );
          final hasPhp = allApps.any(
            (a) => a.isInstalled && a.groupName == 'php',
          );

          if (!hasWebServer || !hasPhp) {
            final error = !hasWebServer
                ? 'Please install Nginx, Apache, or Caddy first.'
                : 'Please install at least one PHP version first.';
            app.addLog('Error: $error');
            throw Exception(error);
          }
        }

        // Update status to installing
        app.status = 'installing';
        app.installProgress = 0.0;
        app.installStatus = 'Starting...';
        app.installLogs = []; // Clear old logs
        notifyUpdate(force: true); // Notify UI of in-memory change

        final installPath = await installer.install(
          app,
          version,
          onProgress: (progress, status, {downloadedBytes, totalBytes}) {
            final statusChanged = app.installStatus != status;
            app.installProgress = progress;
            app.installStatus = status;
            app.downloadedBytes = downloadedBytes;
            app.totalBytes = totalBytes;
            // Force UI refresh on phase changes so status text is never stuck
            // on "Downloading..." while extraction/config is already running.
            notifyUpdate(force: statusChanged);
          },
          onLog: (message) {
            app.addLog(message);
            notifyUpdate();
          },
        );

        app.isInstalled = true;
        app.status = 'installed';
        app.location = installPath;
        app.installedVersion = version;
        app.installedAt = DateTime.now();
        app.installProgress = null;
        app.installStatus = null;

        await repository.save(app);

        // Auto set default PHP if it's the first one
        if (app.groupName == 'php') {
          final allApps = state.valueOrNull ?? [];
          final otherPhp = allApps.where(
            (a) =>
                a.isInstalled && a.groupName == 'php' && a.appId != app.appId,
          );
          if (otherPhp.isEmpty) {
            await repository.setDefaultPhp(app.appId);
            app.isDefault = true;
          }
        }

        // Post-install orchestration
        final allApps = state.valueOrNull ?? [];
        await installer.syncInterAppConfigs(
          app,
          allApps,
          onLog: (m) => app.addLog(m),
        );

        // Auto add to PATH if requested
        if (app.addPathAfterInstall && app.cliFilePath != null) {
          await togglePath(app);
        }

        notifyUpdate(force: true);
      } catch (e) {
        AppLogger.error('Installation failed: $e');
        app.status = 'not_installed';
        app.installProgress = null;
        app.installStatus = null;

        // Notify UI of error
        ref.read(errorNotifierProvider.notifier).setError(e.toString());

        notifyUpdate(force: true);
      }
    } else {
      // Check if it's an update (different version selected)
      if (app.selectedVersion != null &&
          app.selectedVersion != app.installedVersion) {
        final oldPath = app.location;
        final oldVersion = app.installedVersion;
        final newVersion = app.selectedVersion!;
        final installer = ref.read(appInstallerServiceProvider);
        var dataCarried = false;
        var wasInPath = app.isAddedToPath;

        try {
          app.status = 'installing';
          app.installProgress = 0.0;
          app.installStatus = 'Updating to $newVersion...';
          app.installLogs = [];
          notifyUpdate(force: true);

          // 0. Stop service if running before update
          final manager = ref.read(appServiceManagerProvider);
          if (manager.isRunning(app.appId)) {
            AppLogger.info('Stopping service before update: ${app.name}');
            await manager.stop(app);
          }

          // Force-kill only this app's recorded PID (if any). Do NOT use
          // forceKillByNames([execFile, cliFile]) here — an image-name match
          // such as "php.exe" would also kill any unrelated PHP process on
          // the machine.
          final existingPid = app.servicePid ?? 0;
          if (existingPid > 0) {
            await manager.forceKillPid(app.appId, existingPid);
            app.servicePid = null;
          }

          // Safety delay for Windows file handles
          await Future.delayed(const Duration(seconds: 1));

          // 1. Carry the existing data directory over to the new version key
          // BEFORE installing, so initialization sees a populated data dir and
          // skips re-initializing (which would otherwise start from empty).
          dataCarried = await installer.carryOverDataDir(
            app.appId,
            oldVersion,
            newVersion,
            (m) {
              app.addLog(m);
              notifyUpdate();
            },
          );

          // 2. Download and install new version to a new folder
          final newInstallPath = await installer.install(
            app,
            newVersion,
            onProgress: (progress, status, {downloadedBytes, totalBytes}) {
              app.installProgress = progress;
              app.installStatus = status;
              app.downloadedBytes = downloadedBytes;
              app.totalBytes = totalBytes;
              notifyUpdate();
            },
            onLog: (message) {
              app.addLog(message);
              notifyUpdate();
            },
          );

          // 3. Manage PATH if needed
          if (wasInPath) {
            final pathService = ref.read(pathServiceProvider);
            // Remove old shim
            await pathService.removeAppFromPath(app);
            // Add new shim (app object now has new cliFilePath from installer.install)
            await pathService.addAppToPath(app);
            app.isAddedToPath = true;
          }

          // 4. Delete old version folder. Never delete data directories here:
          // this is a version swap, not an uninstall.
          if (oldPath != null) {
            await installer.delete(
              oldPath,
              app.appId,
              oldVersion,
              deleteData: false,
            );
          }

          // 5. Update state
          app.isInstalled = true;
          app.status = 'installed';
          app.location = newInstallPath;
          app.installedVersion = newVersion;
          app.installedAt = DateTime.now();
          app.installProgress = null;
          app.installStatus = null;
          app.selectedVersion = null; // Clear selected version after update

          await repository.save(app);

          // The upgrade is committed: the app now points at $newVersion, so the
          // carried data is where it belongs and must not be rolled back.
          dataCarried = false;

          // Post-install orchestration
          final allApps = state.valueOrNull ?? [];
          await installer.syncInterAppConfigs(
            app,
            allApps,
            onLog: (m) => app.addLog(m),
          );

          // The upgrade is fully committed (persisted + inter-app config
          // synced). If carry-over fell back to copy, the old version-keyed
          // data dir is now a stale, orphaned copy — remove it so disk usage
          // matches the running version. A rename-style carry-over already
          // vacated this path, so this is a no-op for it.
          if (oldVersion != null &&
              AppInstallerService.hasVersionedDataDir(app.appId)) {
            final oldDataDir = Directory(
              p.join(AppConfig.dataDir, '${app.appId}-$oldVersion'),
            );
            if (oldDataDir.existsSync()) {
              try {
                await oldDataDir.delete(recursive: true);
                app.addLog(
                  'Removed orphaned data directory for $oldVersion: '
                  '${oldDataDir.path}',
                );
              } catch (cleanupError) {
                app.addLog(
                  'Could not remove orphaned data directory '
                  '${oldDataDir.path}: $cleanupError',
                );
              }
            }
          }

          notifyUpdate(force: true);
        } catch (e) {
          AppLogger.error('Update failed: $e');

          var userMessage = e.toString();

          // The app is still recorded at $oldVersion, so its data must be too.
          if (dataCarried) {
            try {
              await installer.rollbackCarriedDataDir(
                app.appId,
                oldVersion,
                newVersion,
                (m) {
                  app.addLog(m);
                  notifyUpdate();
                },
              );
            } catch (rollbackError) {
              AppLogger.error(
                'Data rollback failed after a failed update: $rollbackError',
              );
              userMessage =
                  '$userMessage\n\nData rollback also failed: $rollbackError';
            }
          }

          app.status = 'installed'; // Revert to installed
          app.installProgress = null;
          app.installStatus = null;
          app.isAddedToPath = wasInPath;
          if (oldPath != null) {
            app.location = oldPath;
          }
          app.installedVersion = oldVersion;
          app.selectedVersion = null;

          ref.read(errorNotifierProvider.notifier).setError(userMessage);

          notifyUpdate(force: true);
        }
      } else {
        await uninstall(app);
      }
    }

    notifyUpdate(force: true);
  }

  Future<void> uninstall(AppModel app) async {
    final repository = await ref.read(appsRepositoryProvider.future);
    final allApps = state.valueOrNull ?? [];
    try {
      final wasDefault = app.isDefault;

      // Stop service if running
      final manager = ref.read(appServiceManagerProvider);
      if (manager.isRunning(app.appId)) {
        AppLogger.info('Stopping service before uninstallation: ${app.name}');
        await manager.stop(app);
      }

      // Stop whatever is still running. Prefer the recorded PID so we never
      // kill an unrelated process that merely shares an executable name
      // (e.g. a stray "php.exe"). Fall back to image-name kill only when no
      // PID is known.
      final uninstallPid = app.servicePid ?? 0;
      if (uninstallPid > 0) {
        await manager.forceKillPid(app.appId, uninstallPid);
        app.servicePid = null;
      }
      await manager.forceKillByNames([app.execFile ?? '', app.cliFile ?? '']);

      // Safety delay for Windows file handles
      await Future.delayed(const Duration(seconds: 1));

      if (app.location != null) {
        final installer = ref.read(appInstallerServiceProvider);
        if (app.appId == 'pyenv') {
          await installer.cleanupPyenv(app.location!, (m) => app.addLog(m));
        }
        await installer.delete(app.location!, app.appId, app.installedVersion);
      }

      app.isInstalled = false;
      app.isDefault = false;
      app.status = 'not_installed';
      app.installedVersion = null;
      app.location = null;
      app.installedAt = null;
      app.execFilePath = null;
      app.cliFilePath = null;

      await repository.delete(app.appId);

      // 2. Handle Default PHP reassignment
      if (wasDefault && app.groupName == 'php') {
        final remainingPhps = allApps
            .where(
              (a) =>
                  a.isInstalled && a.groupName == 'php' && a.appId != app.appId,
            )
            .toList();
        if (remainingPhps.isNotEmpty) {
          // Find most recently installed
          remainingPhps.sort(
            (a, b) => (b.installedAt ?? DateTime(0)).compareTo(
              a.installedAt ?? DateTime(0),
            ),
          );
          await changeDefaultPhp(remainingPhps.first.appId);
        }
      }

      // Remove from PATH if added
      if (app.isAddedToPath) {
        final pathService = ref.read(pathServiceProvider);
        await pathService.removeAppFromPath(app);
        app.isAddedToPath = false;
      }

      // Remove Composer if this was the last PHP version
      if (app.groupName == 'php') {
        final remainingPhps = allApps.where(
          (a) => a.isInstalled && a.groupName == 'php' && a.appId != app.appId,
        );
        if (remainingPhps.isEmpty) {
          AppLogger.info('Last PHP uninstalled, removing Composer...');
          final installer = ref.read(appInstallerServiceProvider);
          await installer.uninstallComposer();
        }
      }

      notifyUpdate(force: true);
    } catch (e) {
      AppLogger.error('Uninstallation failed: $e');
      ref.read(errorNotifierProvider.notifier).setError(e.toString());
    }
  }

  Future<void> updateCatalog(String url) async {
    state = const AsyncValue.loading();
    try {
      final repository = await ref.read(appsRepositoryProvider.future);
      await repository.updateAppListFromUrl(url);
      await refresh();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> togglePath(AppModel app) async {
    if (!app.isInstalled || app.cliFilePath == null) return;

    final repository = await ref.read(appsRepositoryProvider.future);
    final pathService = ref.read(pathServiceProvider);

    try {
      if (!app.isAddedToPath) {
        await pathService.addAppToPath(app);
        app.isAddedToPath = true;
      } else {
        await pathService.removeAppFromPath(app);
        app.isAddedToPath = false;
      }

      await repository.save(app);
      notifyUpdate(force: true);
    } catch (e) {
      AppLogger.error('Error toggling PATH: $e');
    }
  }

  Future<void> startService(AppModel app) async {
    final manager = ref.read(appServiceManagerProvider);
    final repository = await ref.read(appsRepositoryProvider.future);
    // Persist the autoStart flag only AFTER the service actually starts.
    // Saving it first means a failed start still records "auto-start on boot"
    // for a service that can't run — a lie that survives restarts.
    final previousAutoStart = app.autoStartService;
    try {
      await manager.start(app, onStatusChange: () => notifyUpdate(force: true));

      app.autoStartService = true;
      await repository.save(app);

      // Sync configs if it's a webserver starting
      if (app.categories.contains('webserver')) {
        final installer = ref.read(appInstallerServiceProvider);
        final allApps = state.valueOrNull ?? [];
        await installer.syncInterAppConfigs(app, allApps);
      }

      notifyUpdate(force: true);
    } catch (e) {
      // Restore the flag so a failed start doesn't poison persisted state.
      app.autoStartService = previousAutoStart;
      AppLogger.error('Error starting service: $e');
    }
  }

  Future<void> stopService(AppModel app) async {
    final manager = ref.read(appServiceManagerProvider);
    final repository = await ref.read(appsRepositoryProvider.future);
    final previousAutoStart = app.autoStartService;
    try {
      await manager.stop(app);

      app.autoStartService = false;
      await repository.save(app);

      notifyUpdate(force: true);
    } catch (e) {
      app.autoStartService = previousAutoStart;
      AppLogger.error('Error stopping service: $e');
    }
  }

  Future<void> stopAllServicesQuietly() async {
    final manager = ref.read(appServiceManagerProvider);
    final apps = state.valueOrNull ?? [];

    for (final app in apps) {
      if (manager.isRunning(app.appId)) {
        await manager.stop(app);
      }
    }
    // Không gọi notifyUpdate vì app sắp tắt
  }

  Future<void> reconfigureWebservers({bool restartRunning = true}) async {
    final apps = state.valueOrNull ?? [];
    final installer = ref.read(appInstallerServiceProvider);

    await installer.reconfigureWebservers(
      apps,
      (message) => AppLogger.info('Network Sync: $message'),
    );

    if (restartRunning) {
      await restartRunningWebservers();
    } else {
      notifyUpdate(force: true);
    }
  }

  Future<void> restartRunningWebservers() async {
    final apps = state.valueOrNull ?? [];
    final manager = ref.read(appServiceManagerProvider);

    for (final app in apps.where(
      (app) =>
          app.isInstalled &&
          app.categories.contains('webserver') &&
          manager.isRunning(app.appId),
    )) {
      await manager.restart(
        app,
        onStatusChange: () => notifyUpdate(force: true),
      );
    }

    notifyUpdate(force: true);
  }

  Future<void> restartService(
    AppModel app, {
    bool rethrowOnError = false,
  }) async {
    final manager = ref.read(appServiceManagerProvider);
    try {
      await manager.restart(
        app,
        onStatusChange: () => notifyUpdate(force: true),
      );
      notifyUpdate(force: true);
    } catch (e) {
      AppLogger.error('Error restarting service: $e');
      // By default this is fire-and-forget from UI buttons, so we don't
      // surface the failure. Callers that must know whether the restart
      // actually succeeded (e.g. the webserver restart coalescer in
      // SitesNotifier) pass [rethrowOnError: true] so a silent "success"
      // can't mask a failed reload of config changes.
      if (rethrowOnError) rethrow;
    }
  }

  Future<void> changeDefaultPhp(String appId) async {
    try {
      final repository = await ref.read(appsRepositoryProvider.future);
      final allApps = state.valueOrNull ?? [];

      // 1. Update DB
      await repository.setDefaultPhp(appId);

      // 2. Update local state
      for (final a in allApps) {
        if (a.groupName == 'php') {
          a.isDefault = (a.appId == appId);
        }
      }

      // 3. Sync configs (PMA needs to point to new PHP port)
      final installer = ref.read(appInstallerServiceProvider);
      final targetApp = allApps.firstWhere((a) => a.appId == appId);
      await installer.syncInterAppConfigs(targetApp, allApps);

      // 4. Restart Web Servers if running
      final manager = ref.read(appServiceManagerProvider);
      final webServers = allApps.where(
        (a) => a.isInstalled && a.categories.contains('webserver'),
      );
      for (final ws in webServers) {
        if (manager.isRunning(ws.appId)) {
          AppLogger.info('Restarting ${ws.name} due to default PHP change...');
          await manager.restart(
            ws,
            onStatusChange: () => notifyUpdate(force: true),
          );
        }
      }

      notifyUpdate(force: true);
    } catch (e) {
      AppLogger.error('Error changing default PHP: $e');
      ref
          .read(errorNotifierProvider.notifier)
          .setError('Failed to change default PHP: $e');
    }
  }

  Future<void> openApp(AppModel app) async {
    if (!app.isInstalled) return;

    // Special handling for RustFS Dashboard
    if (app.appId == 'rustfs') {
      try {
        final settings = await ref
            .read(rustFSSettingsProvider.notifier)
            .readConfig();
        final consoleAddress = settings['console_address'] ?? ':9001';
        final port = consoleAddress.split(':').last;
        final url = 'http://localhost:$port';

        if (await canLaunchUrlString(url)) {
          await launchUrlString(url);
        } else {
          throw Exception('Could not launch $url');
        }
        return;
      } catch (e) {
        AppLogger.error('Error opening RustFS dashboard: $e');
        ref
            .read(errorNotifierProvider.notifier)
            .setError('Failed to open RustFS Dashboard: $e');
        return;
      }
    }

    // Special handling for Meilisearch Dashboard
    if (app.appId == 'meilisearch') {
      try {
        final settings = await ref
            .read(meilisearchSettingsProvider.notifier)
            .readConfig(app);
        final httpAddr = settings['http_addr'] ?? '127.0.0.1:7700';

        // Handle both "127.0.0.1:7700" and ":7700" formats
        String url;
        if (httpAddr.startsWith(':')) {
          url = 'http://localhost$httpAddr';
        } else {
          url = 'http://$httpAddr';
        }

        if (await canLaunchUrlString(url)) {
          await launchUrlString(url);
        } else {
          throw Exception('Could not launch $url');
        }
        return;
      } catch (e) {
        AppLogger.error('Error opening Meilisearch dashboard: $e');
        ref
            .read(errorNotifierProvider.notifier)
            .setError('Failed to open Meilisearch Dashboard: $e');
        return;
      }
    }

    if (app.execFilePath == null) return;

    try {
      final file = File(app.execFilePath!);
      if (await file.exists()) {
        await Process.run('cmd', ['/c', 'start', '', app.execFilePath!]);
      } else {
        throw Exception('Executable not found at ${app.execFilePath}');
      }
    } catch (e) {
      AppLogger.error('Error opening app: $e');
      ref
          .read(errorNotifierProvider.notifier)
          .setError('Failed to open ${app.name}: $e');
    }
  }

  Future<void> stopAllServices() async {
    final apps = state.valueOrNull ?? [];
    final manager = ref.read(appServiceManagerProvider);

    // Lọc ra các app đang chạy
    final runningApps = apps
        .where(
          (app) =>
              app.isInstalled && app.isService && manager.isRunning(app.appId),
        )
        .toList();

    AppLogger.info('Tray: Stopping ${runningApps.length} services...');

    // Dừng tất cả song song để tăng tốc độ
    await Future.wait(
      runningApps.map((app) async {
        try {
          await manager.stop(app);
          app.serviceStatus = 'stopped';
        } catch (e) {
          AppLogger.error('Error stopping ${app.name}: $e');
        }
      }),
    );

    notifyUpdate(force: true);
  }
}
