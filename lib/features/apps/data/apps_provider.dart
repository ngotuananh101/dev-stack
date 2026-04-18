import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/database/isar_provider.dart';
import '../domain/app_model.dart';
import 'apps_repository.dart';
import 'app_installer_service.dart';

part 'apps_provider.g.dart';

@riverpod
Future<AppsRepository> appsRepository(AppsRepositoryRef ref) async {
  final isar = await ref.watch(isarProvider.future);
  return AppsRepository(isar);
}

@riverpod
class AppsNotifier extends _$AppsNotifier {
  @override
  Future<List<AppModel>> build() async {
    final repository = await ref.watch(appsRepositoryProvider.future);
    
    // Import initial data if needed
    await repository.importInitialData();
    
    return await repository.getAll();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = await ref.read(appsRepositoryProvider.future);
      return await repository.getAll();
    });
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
        await refresh(); // Notify UI

        final installPath = await installer.install(
          app, 
          version,
          onProgress: (progress, status) {
            app.installProgress = progress;
            app.installStatus = status;
            refresh(); // Triggers UI update via Notifier
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
      } catch (e) {
        print('Installation failed: $e');
        app.status = 'not_installed';
        app.installProgress = null;
        app.installStatus = null;
      }
    } else {
      // Logic for uninstalling could go here
      app.isInstalled = false;
      app.status = 'not_installed';
      await repository.delete(app.appId);
    }
    
    await refresh();
  }
}
