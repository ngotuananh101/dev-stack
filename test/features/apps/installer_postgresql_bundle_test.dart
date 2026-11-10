import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dev_stack/core/config/app_config.dart';
import 'package:dev_stack/core/services/log_service.dart';
import 'package:dev_stack/features/apps/data/app_installer_service.dart';
import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:dev_stack/features/settings/domain/app_settings.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../helpers/runtime_bundle_fixture.dart';
import '../../helpers/test_ref.dart';

/// Serves one pre-built archive for the builder bundle URL under test.
class _BundleAdapter implements HttpClientAdapter {
  final List<int> bytes;
  final String url;
  _BundleAdapter(this.bytes, this.url);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.uri.toString() != url) {
      throw StateError('Unexpected test download: ${options.uri}');
    }
    return ResponseBody.fromBytes(
      bytes,
      200,
      headers: {
        Headers.contentLengthHeader: ['${bytes.length}'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

List<int> postgresqlBundleArchive(String rootName) {
  final tempFixtureDir = Directory.systemTemp.createTempSync('pg_fixture_');
  try {
    final root = createPostgresqlBundleFixture(tempFixtureDir);
    final initdbFile = File(p.join(root.path, 'bin', 'initdb'));
    initdbFile.writeAsStringSync('''#!/bin/sh
set -eu
while [ "\$#" -gt 0 ]; do
  if [ "\$1" = "-D" ]; then dir="\$2"; shift 2; continue; fi
  shift
done
mkdir -p "\$dir"
printf "listen_addresses = 'localhost'\\n" > "\$dir/postgresql.conf"
''');

    final archive = Archive();
    for (final entity in root.listSync(recursive: true)) {
      if (entity is File) {
        final rel = p.relative(entity.path, from: root.path);
        final content = entity.readAsBytesSync();
        final file = ArchiveFile('$rootName/$rel', content.length, content);
        if (rel.startsWith('bin/')) {
          file.mode = 0x1ED; // 0755
        }
        archive.addFile(file);
      }
    }
    return GZipEncoder().encode(TarEncoder().encode(archive));
  } finally {
    tempFixtureDir.deleteSync(recursive: true);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory parent;

  setUp(() {
    parent = Directory.systemTemp.createTempSync('pg_bundle_setup_');
    AppConfig.initialize(baseDir: p.join(parent.path, 'app data'));
  });

  tearDown(() => parent.deleteSync(recursive: true));

  test(
    'installing a portable PostgreSQL bundle initializes cluster through configureIsolatedPostgresql',
    () async {
      const name = 'postgresql-18.6-musl-x86_64-abcdef0123456789';
      final url =
          'https://github.com/ngotuananh101/devstack-app-builder/'
          'releases/download/runtimes-2026-11-06/$name.tar.gz';
      final dio = Dio()
        ..httpClientAdapter = _BundleAdapter(
          postgresqlBundleArchive(name),
          url,
        );
      final service = AppInstallerService(LogService(), testRef(), dio: dio);

      final app = AppModel(
        appId: 'postgresql',
        name: 'PostgreSQL',
        categories: const ['database'],
        groupName: 'database',
        execFile: 'postgres',
        cliFile: 'psql',
        versionLinksJson: '{"18.6":"$url"}',
      );

      final logs = <String>[];
      final installPath = await service.install(app, '18.6', onLog: logs.add);

      expect(app.execFilePath, p.join(installPath, 'bin', 'postgres'));
      expect(File(p.join(installPath, 'bin', 'postgres')).existsSync(), isTrue);
      final dataDir = p.join(AppConfig.dataDir, 'postgresql-18.6');
      expect(
        File(p.join(dataDir, 'postgresql.conf')).readAsStringSync(),
        contains("listen_addresses = '127.0.0.1'"),
      );
      expect(
        File(p.join(dataDir, 'postgres-password.txt')).existsSync(),
        isTrue,
      );
    },
    skip: !Platform.isLinux
        ? 'PostgreSQL musl bundle installer test is Linux-only'
        : false,
  );

  test(
    'installing a portable PostgreSQL bundle respects allowLanAccess setting',
    () async {
      const name = 'postgresql-18.6-musl-x86_64-abcdef0123456789';
      final url =
          'https://github.com/ngotuananh101/devstack-app-builder/'
          'releases/download/runtimes-2026-11-06/$name.tar.gz';
      final dio = Dio()
        ..httpClientAdapter = _BundleAdapter(
          postgresqlBundleArchive(name),
          url,
        );
      final container = createTestRefContainer(
        settings: AppSettings()..allowLanAccess = true,
      );
      final service = AppInstallerService(
        LogService(),
        testRef(container),
        dio: dio,
      );

      final app = AppModel(
        appId: 'postgresql',
        name: 'PostgreSQL',
        categories: const ['database'],
        groupName: 'database',
        execFile: 'postgres',
        cliFile: 'psql',
        versionLinksJson: '{"18.6":"$url"}',
      );

      final logs = <String>[];
      await service.install(app, '18.6', onLog: logs.add);

      final dataDir = p.join(AppConfig.dataDir, 'postgresql-18.6');
      expect(
        File(p.join(dataDir, 'postgresql.conf')).readAsStringSync(),
        contains("listen_addresses = '*'"),
      );
    },
    skip: !Platform.isLinux
        ? 'PostgreSQL musl bundle installer test is Linux-only'
        : false,
  );
}
