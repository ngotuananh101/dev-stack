import 'dart:io';

import 'package:dev_stack/features/sites/domain/site_model.dart';
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
  final libraryPath = _isarLibraryPath();

  setUp(() {
    final tempDir = Directory.systemTemp.createTempSync('devstack_sites_test_');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    Isar.initialize(libraryPath);
    isar = Isar.open(
      schemas: [SiteModelSchema],
      directory: tempDir.path,
      name: 'sites_repo_test_${DateTime.now().microsecondsSinceEpoch}',
    );
    addTearDown(isar.close);
  });

  group('SiteModel auto-increment persistence', () {
    test(
      'creating multiple sites with autoIncrement assigns unique IDs',
      () {
        final site1 = SiteModel(
          id: isar.siteModels.autoIncrement(),
          domain: 'site1.test',
          rootDir: 'C:\\sites\\site1',
        );
        final site2 = SiteModel(
          id: isar.siteModels.autoIncrement(),
          domain: 'site2.test',
          rootDir: 'C:\\sites\\site2',
        );

        isar.write((_) {
          isar.siteModels.put(site1);
          isar.siteModels.put(site2);
        });

        final all = isar.siteModels.where().findAll();
        expect(all.length, equals(2));
        expect(all.map((s) => s.domain).toSet(), containsAll(['site1.test', 'site2.test']));
        expect(all.map((s) => s.id).toSet().length, equals(2));
      },
      skip: libraryPath == null ? 'Isar native library not available' : false,
    );
  });
}
