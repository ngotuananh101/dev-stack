import 'dart:io';

import 'package:dev_stack/core/database/isar_provider.dart';
import 'package:dev_stack/features/apps/data/apps_provider.dart';
import 'package:dev_stack/features/apps/data/apps_repository.dart';
import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:dev_stack/features/apps/domain/installed_app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

String? _isarLibraryPath() {
  final libName = Platform.isWindows
      ? 'isar_plus.dll'
      : (Platform.isLinux ? 'libisar_plus.so' : null);
  if (libName == null) return null;

  final pubCache = Platform.environment['PUB_CACHE'] ??
      (Platform.isWindows
          ? '${Platform.environment['LOCALAPPDATA']}\\Pub\\Cache'
          : '${Platform.environment['HOME']}/.pub-cache');
  final hosted = Directory('$pubCache/hosted/pub.dev');
  if (!hosted.existsSync()) return null;

  for (final entry in hosted.listSync()) {
    if (entry is! Directory) continue;
    if (!entry.path.contains('isar_plus_flutter_libs-')) continue;
    final candidate = File(
      '${entry.path}/${Platform.isWindows ? 'windows' : 'linux'}/$libName',
    );
    if (candidate.existsSync()) return candidate.path;
  }
  return null;
}

void main() {
  late Isar isar;
  late AppsRepository repository;
  final libraryPath = _isarLibraryPath();

  setUp(() {
    final tempDir = Directory.systemTemp.createTempSync('devstack_screen_switch_test_');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    Isar.initialize(libraryPath);
    isar = Isar.open(
      schemas: [InstalledAppSchema],
      directory: tempDir.path,
      name: 'screen_switch_test_${DateTime.now().microsecondsSinceEpoch}',
    );
    addTearDown(isar.close);
    repository = AppsRepository(isar);
  });

  ProviderContainer createContainer() => ProviderContainer.test(
    overrides: [
      isarProvider.overrideWith((ref) async => isar),
      appsRepositoryProvider.overrideWith((ref) async => repository),
    ],
  );

  test(
    'installed apps persist across refresh and multiple autoUpdateCatalog invocations',
    () async {
      // 1. Pre-populate repository with 2 installed apps
      final app1 = AppModel(
        appId: 'nginx',
        name: 'Nginx',
        description: 'Web server',
        categories: ['webserver'],
        versions: ['1.24.0'],
        installMethod: 'download',
        isInstalled: true,
        status: 'installed',
        installedVersion: '1.24.0',
        location: 'C:\\test\\nginx',
        installedAt: DateTime.now(),
      );
      final app2 = AppModel(
        appId: 'php82',
        name: 'PHP 8.2',
        description: 'PHP interpreter',
        categories: ['runtime'],
        groupName: 'php',
        versions: ['8.2.0'],
        installMethod: 'download',
        isInstalled: true,
        status: 'installed',
        installedVersion: '8.2.0',
        location: 'C:\\test\\php82',
        installedAt: DateTime.now(),
      );

      await repository.save(app1);
      await repository.save(app2);

      // Verify Isar has both records with distinct IDs
      final isarApps = isar.installedApps.where().findAll();
      expect(isarApps.length, equals(2));
      expect(isarApps.map((a) => a.appId).toSet(), equals({'nginx', 'php82'}));

      final container = createContainer();
      addTearDown(container.dispose);

      // 2. Simulate screen switch: first visit
      final appsNotifier = container.read(appsProvider.notifier);
      await appsNotifier.autoUpdateCatalog();

      // 3. Simulate second screen switch (user navigates away and back)
      await appsNotifier.autoUpdateCatalog();

      // Verify that the database still retains both installed apps
      final isarAppsAfter = isar.installedApps.where().findAll();
      expect(isarAppsAfter.length, equals(2));
      expect(isarAppsAfter.map((a) => a.appId).toSet(), equals({'nginx', 'php82'}));
    },
    skip: libraryPath == null ? 'Isar native library not available' : false,
  );
}
