import 'dart:io';

import 'package:dev_stack/core/services/log_service.dart';
import 'package:dev_stack/features/apps/data/app_launcher.dart';
import 'package:dev_stack/features/apps/data/app_service_manager.dart';
import 'package:dev_stack/features/apps/data/apps_provider.dart';
import 'package:dev_stack/features/apps/data/apps_repository.dart';
import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:dev_stack/shared/providers/error_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const _catalogUrl = 'https://example.test/catalog.json';

class _CatalogRepository implements AppsRepository {
  List<AppModel> apps;
  List<AppModel>? downloadedApps;
  Object? downloadError;
  Object? loadError;

  _CatalogRepository(this.apps);

  @override
  Future<List<AppModel>> getAll() async {
    if (loadError != null) throw loadError!;
    return apps;
  }

  @override
  Future<void> updateAppListFromUrl(String url) async {
    if (url != _catalogUrl) throw StateError('Unexpected catalog URL: $url');
    if (downloadError != null) throw downloadError!;
    if (downloadedApps != null) apps = downloadedApps!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Services extends AppServiceManager {
  _Services() : super(LogService());

  @override
  void syncAppState(AppModel app) {}
}

void main() {
  late _CatalogRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = _CatalogRepository([
      AppModel(appId: 'nginx', name: 'Nginx', categories: const ['webserver']),
    ]);
    container = ProviderContainer.test(
      retry: (retryCount, error) => null,
      overrides: [
        appsRepositoryProvider.overrideWith((ref) async => repository),
        appServiceManagerProvider.overrideWithValue(_Services()),
      ],
    );
  });

  test(
    'failed catalog download rethrows and preserves the current apps',
    () async {
      final previous = await container.read(appsProvider.future);
      const failure = FormatException('Missing catalog name');
      repository.downloadError = failure;

      await expectLater(
        container.read(appsProvider.notifier).updateCatalog(_catalogUrl),
        throwsA(same(failure)),
      );

      final state = container.read(appsProvider);
      expect(state, isA<AsyncData<List<AppModel>>>());
      expect(state.requireValue, same(previous));
      expect(state.requireValue.single.name, 'Nginx');
    },
  );

  test('failed reload rethrows and preserves the current apps', () async {
    final previous = await container.read(appsProvider.future);
    const failure = FormatException('Invalid cached catalog');
    repository.loadError = failure;

    await expectLater(
      container.read(appsProvider.notifier).updateCatalog(_catalogUrl),
      throwsA(same(failure)),
    );

    expect(container.read(appsProvider), isA<AsyncData<List<AppModel>>>());
    expect(container.read(appsProvider).requireValue, same(previous));
  });

  test('successful catalog update replaces the app list', () async {
    await container.read(appsProvider.future);
    repository.downloadedApps = [
      AppModel(appId: 'redis', name: 'Redis', categories: const ['database']),
    ];

    await container.read(appsProvider.notifier).updateCatalog(_catalogUrl);

    final state = container.read(appsProvider);
    expect(state, isA<AsyncData<List<AppModel>>>());
    expect(state.requireValue.single.appId, 'redis');
    expect(state.requireValue.single.name, 'Redis');
  });

  test(
    'update failure without a previous list retains an error state',
    () async {
      repository.loadError = const FormatException(
        'Initial catalog is invalid',
      );
      await expectLater(
        container.read(appsProvider.future),
        throwsFormatException,
      );
      const failure = FormatException('Downloaded catalog is invalid');
      repository.downloadError = failure;

      await expectLater(
        container.read(appsProvider.notifier).updateCatalog(_catalogUrl),
        throwsA(same(failure)),
      );

      expect(container.read(appsProvider), isA<AsyncError<List<AppModel>>>());
      expect(container.read(appsProvider).error, same(failure));
    },
  );

  test(
    'opening Compass routes process failures to the app error state',
    () async {
      final root = Directory.systemTemp.createTempSync('compass_open_');
      addTearDown(() => root.deleteSync(recursive: true));
      final executable = File(p.join(root.path, 'MongoDB Compass'))
        ..createSync();
      final app = AppModel(
        appId: 'mongodb-compass',
        name: 'MongoDB Compass',
        categories: const ['tool'],
        isInstalled: true,
        execFilePath: executable.path,
      );
      repository.apps = [app];
      final attempts = <String>[];
      final openContainer = ProviderContainer.test(
        overrides: [
          appsRepositoryProvider.overrideWith((ref) async => repository),
          appServiceManagerProvider.overrideWithValue(_Services()),
          appLauncherProvider.overrideWithValue(
            AppLauncher(
              isLinux: true,
              startDetached: (path, _, _) async {
                attempts.add(path);
                throw ProcessException(path, [], 'permission denied');
              },
            ),
          ),
        ],
      );
      final installed = (await openContainer.read(appsProvider.future)).single;
      await openContainer.read(appsProvider.notifier).openApp(installed);

      expect(attempts, [executable.absolute.path]);
      expect(
        openContainer.read(appErrorProvider),
        allOf(
          startsWith('Failed to open MongoDB Compass:'),
          contains('permission denied'),
        ),
      );
    },
  );

  test('a valid update recovers from an initial catalog error', () async {
    repository.loadError = const FormatException('Initial catalog is invalid');
    await expectLater(
      container.read(appsProvider.future),
      throwsFormatException,
    );
    repository.loadError = null;
    repository.downloadedApps = [
      AppModel(appId: 'redis', name: 'Redis', categories: const ['database']),
    ];

    await container.read(appsProvider.notifier).updateCatalog(_catalogUrl);

    expect(container.read(appsProvider).requireValue.single.name, 'Redis');
  });
}
