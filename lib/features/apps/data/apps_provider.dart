import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/database/isar_provider.dart';
import '../domain/app_model.dart';
import 'apps_repository.dart';

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
    app.isInstalled = !app.isInstalled;
    await repository.save(app);
    await refresh();
  }
}
