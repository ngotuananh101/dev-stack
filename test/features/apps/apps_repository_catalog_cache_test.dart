import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dev_stack/features/apps/data/apps_repository.dart';
import 'package:dev_stack/features/apps/domain/installed_app.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';
import 'package:path/path.dart' as p;

const _catalogUrl = 'https://example.test/catalog.json';

class _CatalogAdapter implements HttpClientAdapter {
  final String body;
  _CatalogAdapter(this.body);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.uri.toString() != _catalogUrl) {
      throw StateError('Unexpected catalog request: ${options.uri}');
    }
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

String? _isarLibraryPath() {
  if (!Platform.isLinux && !Platform.isWindows) return null;
  final libName = Platform.isWindows ? 'isar_plus.dll' : 'libisar_plus.so';
  final pubCache =
      Platform.environment['PUB_CACHE'] ??
      (Platform.isWindows
          ? '${Platform.environment['LOCALAPPDATA']}\\Pub\\Cache'
          : '${Platform.environment['HOME']}/.pub-cache');
  final hosted = Directory('$pubCache/hosted/pub.dev');
  if (!hosted.existsSync()) return null;
  for (final entry in hosted.listSync()) {
    if (entry is! Directory ||
        !entry.path.contains('isar_plus_flutter_libs-')) {
      continue;
    }
    final candidate = File(
      p.join(entry.path, Platform.isWindows ? 'windows' : 'linux', libName),
    );
    if (candidate.existsSync()) return candidate.path;
  }
  return null;
}

String _catalog(List<Map<String, dynamic>> apps) =>
    jsonEncode({'version': 'test', 'apps': apps});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final catalogFileName = AppsRepository.catalogFileNameFor(
    isLinux: Platform.isLinux,
  );
  late Directory supportDir;
  late File cache;

  setUp(() {
    supportDir = Directory.systemTemp.createTempSync('devstack_catalog_');
    cache = File(p.join(supportDir.path, catalogFileName));
  });

  tearDown(() => supportDir.deleteSync(recursive: true));

  AppsRepository repository(String responseBody, [Isar? isar]) =>
      AppsRepository.withDependencies(
        isar,
        dio: Dio()..httpClientAdapter = _CatalogAdapter(responseBody),
        supportDirectory: () async => supportDir,
      );

  test(
    'invalid downloaded catalog does not replace the cached catalog',
    () async {
      const previous = '{"apps":[{"id":"nginx","name":"Nginx"}]}';
      cache.writeAsStringSync(previous);
      final invalid = _catalog([
        {'id': 'redis', 'category': 'database', 'versions': {}},
      ]);

      await expectLater(
        repository(invalid).updateAppListFromUrl(_catalogUrl),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('name'),
          ),
        ),
      );
      expect(cache.readAsStringSync(), previous);
    },
  );

  test('valid downloaded catalog is saved', () async {
    final valid = _catalog([
      {'id': 'redis', 'name': 'Redis', 'category': 'database', 'versions': {}},
    ]);

    await repository(valid).updateAppListFromUrl(_catalogUrl);

    expect(jsonDecode(cache.readAsStringSync()), jsonDecode(valid));
  });

  const malformedCatalogs = {
    'invalid JSON': '{',
    'null root': 'null',
    'missing apps': '{}',
    'non-list apps': '{"apps":"redis"}',
    'non-object app': '{"apps":[null]}',
    'invalid optional string':
        '{"apps":[{"id":"redis","name":"Redis","description":42}]}',
    'invalid category element':
        '{"apps":[{"id":"redis","name":"Redis","category":[null]}]}',
  };
  for (final entry in malformedCatalogs.entries) {
    test('rejects ${entry.key} without replacing the cache', () async {
      const previous = '{"apps":[{"id":"nginx","name":"Nginx"}]}';
      cache.writeAsStringSync(previous);

      await expectLater(
        repository(entry.value).updateAppListFromUrl(_catalogUrl),
        entry.key == 'invalid JSON'
            ? throwsA(isA<Exception>())
            : throwsFormatException,
      );

      expect(cache.readAsStringSync(), previous);
    });
  }

  final libraryPath = _isarLibraryPath();
  Isar openTestDatabase() {
    final dbDir = Directory(p.join(supportDir.path, 'db'))..createSync();
    Isar.initialize(libraryPath);
    final isar = Isar.open(
      schemas: [InstalledAppSchema],
      directory: dbDir.path,
      name: 'catalog_cache_${DateTime.now().microsecondsSinceEpoch}',
    );
    addTearDown(isar.close);
    return isar;
  }

  final skipLinuxIntegration = !Platform.isLinux
      ? 'Requires the Linux catalog'
      : libraryPath == null
      ? 'Isar native library not available'
      : false;

  test(
    'legacy Linux cache adds only bundled Compass and retains its installed state',
    () async {
      final isar = openTestDatabase();
      final location = p.join(supportDir.path, 'installed', 'compass');
      final executable = p.join(location, 'MongoDB Compass');
      isar.write((_) {
        isar.installedApps.put(
          InstalledApp(
            appId: 'mongodb-compass',
            appName: 'MongoDB Compass',
            location: location,
            status: 'stopped',
            version: '1.53.2',
            execFilePath: executable,
          )..id = isar.installedApps.autoIncrement(),
        );
      });
      final legacy = _catalog([
        {
          'id': 'redis',
          'name': 'Cached Redis',
          'versions': {'9.0.0': 'https://example.test/redis.tar.gz'},
        },
      ]);
      cache.writeAsStringSync(legacy);

      final apps = await repository('{}', isar).getAll();
      expect(
        apps.map((app) => app.appId),
        unorderedEquals(['redis', 'mongodb-compass']),
      );
      final redis = apps.singleWhere((app) => app.appId == 'redis');
      expect(redis.name, 'Cached Redis');
      expect(redis.versionLinks, {
        '9.0.0': 'https://example.test/redis.tar.gz',
      });
      final compass = apps.singleWhere((app) => app.appId == 'mongodb-compass');
      expect(compass.isInstalled, isTrue);
      expect(compass.installedVersion, '1.53.2');
      expect(compass.location, location);
      expect(compass.execFilePath, executable);
      expect(compass.versions, isNotEmpty);
      expect(cache.readAsStringSync(), legacy);
    },
    skip: skipLinuxIntegration,
  );

  test(
    'Linux cache with Compass keeps its own version without duplicates',
    () async {
      final isar = openTestDatabase();
      cache.writeAsStringSync(
        _catalog([
          {
            'id': 'mongodb-compass',
            'name': 'Cached Compass',
            'versions': {
              '1.88.0':
                  'https://github.com/mongodb-js/compass/releases/download/v1.88.0/mongodb-compass-1.88.0-linux-x64.tar.gz',
            },
            'sha256': {'1.88.0': 'a' * 64},
          },
        ]),
      );

      final compass = (await repository('{}', isar).getAll()).single;
      expect(compass.appId, 'mongodb-compass');
      expect(compass.name, 'Cached Compass');
      expect(compass.versions, ['1.88.0']);
      expect(compass.versionSha256, {'1.88.0': 'a' * 64});
    },
    skip: skipLinuxIntegration,
  );

  test('invalid cached catalog falls back to the bundled catalog', () async {
    final isar = openTestDatabase();
    final invalid = _catalog([
      {'id': 'redis', 'category': 'database', 'versions': {}},
    ]);
    cache.writeAsStringSync(invalid);

    final apps = await repository('{}', isar).getAll();

    expect(apps.singleWhere((app) => app.appId == 'redis').name, 'Redis');
    expect(cache.readAsStringSync(), invalid);
  }, skip: libraryPath == null ? 'Isar native library not available' : false);
}
