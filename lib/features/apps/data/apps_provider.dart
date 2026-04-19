import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/database/isar_provider.dart';
import '../domain/app_model.dart';
import 'apps_repository.dart';
import 'app_installer_service.dart';

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
    
    // Import initial data if needed
    try {
      await repository.importInitialData();
    } catch (e) {
      debugPrint('Error in importInitialData: $e');
    }
    
    return await repository.getAll();
  }

  Future<void> refresh() async {
    final repository = await ref.read(appsRepositoryProvider.future);
    final list = await repository.getAll();
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
    
    if (!app.isInstalled) {
      try {
        final version = app.selectedVersion ?? 'latest';
        final installer = ref.read(appInstallerServiceProvider);
        
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
        
        app.isInstalled = true;
        app.status = 'installed';
        app.location = installPath;
        app.installedVersion = version;
        app.installedAt = DateTime.now();
        app.installProgress = null;
        app.installStatus = null;
        
        await repository.save(app);
        notifyUpdate(force: true);
      } catch (e) {
        debugPrint('Installation failed: $e');
        app.status = 'not_installed';
        app.installProgress = null;
        app.installStatus = null;
        notifyUpdate(force: true);
      }
    } else {
      // Logic for uninstalling
      try {
        if (app.location != null) {
          final installer = ref.read(appInstallerServiceProvider);
          await installer.delete(app.location!);
        }
        
        app.isInstalled = false;
        app.status = 'not_installed';
        app.installedVersion = null;
        app.location = null;
        app.installedAt = null;
        app.execFilePath = null;
        app.cliFilePath = null;
        
        await repository.delete(app.appId);
      } catch (e) {
        debugPrint('Uninstallation failed: $e');
      }
    }
    
    notifyUpdate(force: true);
  }

  Future<void> uninstall(AppModel app) async {
    final repository = await ref.read(appsRepositoryProvider.future);
    try {
      if (app.location != null) {
        final installer = ref.read(appInstallerServiceProvider);
        await installer.delete(app.location!);
      }
      
      app.isInstalled = false;
      app.status = 'not_installed';
      app.installedVersion = null;
      app.location = null;
      app.installedAt = null;
      app.execFilePath = null;
      app.cliFilePath = null;
      
      await repository.delete(app.appId);
      notifyUpdate(force: true);
    } catch (e) {
      debugPrint('Uninstallation failed: $e');
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
}
