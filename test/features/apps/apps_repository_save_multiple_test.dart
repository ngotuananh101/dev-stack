import 'dart:io';

import 'package:dev_stack/features/apps/data/apps_repository.dart';
import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:dev_stack/features/apps/domain/installed_app.dart';
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
    final tempDir = Directory.systemTemp.createTempSync('devstack_apps_test_');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    Isar.initialize(libraryPath);
    isar = Isar.open(
      schemas: [InstalledAppSchema],
      directory: tempDir.path,
      name: 'apps_repo_test_${DateTime.now().microsecondsSinceEpoch}',
    );
    addTearDown(isar.close);
    repository = AppsRepository(isar);
  });

  AppModel makeApp(String id, String name, {String version = '1.0.0'}) {
    return AppModel(
      appId: id,
      name: name,
      description: 'Test $name',
      categories: ['test'],
      versions: [version],
      installMethod: 'download',
      isInstalled: true,
      status: 'installed',
      installedVersion: version,
      location: 'C:\\test\\$id',
      installedAt: DateTime.now(),
    );
  }

  group('AppsRepository.save multi-app persistence', () {
    test(
      'saving multiple apps does not overwrite existing records with id=0',
      () async {
        final app1 = makeApp('nginx', 'Nginx');
        final app2 = makeApp('php82', 'PHP 8.2');
        final app3 = makeApp('mysql', 'MySQL');

        await repository.save(app1);
        await repository.save(app2);
        await repository.save(app3);

        final all = isar.installedApps.where().findAll();
        expect(all.length, equals(3), reason: 'All 3 apps must be stored, not overwritten');

        final appIds = all.map((a) => a.appId).toSet();
        expect(appIds, containsAll(['nginx', 'php82', 'mysql']));

        final ids = all.map((a) => a.id).toSet();
        expect(ids.length, equals(3), reason: 'Each app must have a distinct primary key id');
      },
      skip: libraryPath == null ? 'Isar native library not available' : false,
    );

    test(
      'updating an existing app preserves its id and does not overwrite other apps',
      () async {
        final app1 = makeApp('nginx', 'Nginx', version: '1.24.0');
        final app2 = makeApp('php82', 'PHP 8.2', version: '8.2.0');

        await repository.save(app1);
        await repository.save(app2);

        // Update app1 to a new version
        final app1Updated = makeApp('nginx', 'Nginx', version: '1.26.0');
        await repository.save(app1Updated);

        final all = isar.installedApps.where().findAll();
        expect(all.length, equals(2));

        final nginx = isar.installedApps.where().appIdEqualTo('nginx').findFirst();
        expect(nginx, isNotNull);
        expect(nginx!.version, equals('1.26.0'));

        final php = isar.installedApps.where().appIdEqualTo('php82').findFirst();
        expect(php, isNotNull);
        expect(php!.version, equals('8.2.0'));
      },
      skip: libraryPath == null ? 'Isar native library not available' : false,
    );
  });
}
