import 'dart:io';

import 'package:dev_stack/features/databases/domain/database_record.dart';
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
    final tempDir = Directory.systemTemp.createTempSync('devstack_db_test_');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    Isar.initialize(libraryPath);
    isar = Isar.open(
      schemas: [DatabaseRecordSchema],
      directory: tempDir.path,
      name: 'db_repo_test_${DateTime.now().microsecondsSinceEpoch}',
    );
    addTearDown(isar.close);
  });

  group('DatabaseRecord auto-increment persistence', () {
    test(
      'creating multiple database records with autoIncrement assigns unique IDs',
      () {
        final rec1 = DatabaseRecord()
          ..id = isar.databaseRecords.autoIncrement()
          ..name = 'db1'
          ..username = 'root'
          ..password = ''
          ..engineAppId = 'mysql'
          ..createdAt = DateTime.now();

        final rec2 = DatabaseRecord()
          ..id = isar.databaseRecords.autoIncrement()
          ..name = 'db2'
          ..username = 'root'
          ..password = ''
          ..engineAppId = 'mysql'
          ..createdAt = DateTime.now();

        isar.write((_) {
          isar.databaseRecords.put(rec1);
          isar.databaseRecords.put(rec2);
        });

        final all = isar.databaseRecords.where().findAll();
        expect(all.length, equals(2));
        expect(all.map((d) => d.name).toSet(), containsAll(['db1', 'db2']));
        expect(all.map((d) => d.id).toSet().length, equals(2));
      },
      skip: libraryPath == null ? 'Isar native library not available' : false,
    );
  });
}
