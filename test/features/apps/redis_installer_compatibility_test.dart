import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dev_stack/core/config/app_config.dart';
import 'package:dev_stack/core/services/log_service.dart';
import 'package:dev_stack/features/apps/data/app_installer_service.dart';
import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

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

/// Builds the archive the Redis builder publishes: one root directory holding
/// `bin/redis-server`, its aliases and the license/manifest side files.
List<int> redisBundleArchive(String rootName) {
  final archive = Archive();
  void add(String path, List<int> content, {bool executable = false}) {
    final file = ArchiveFile('$rootName/$path', content.length, content);
    if (executable) file.mode = 0x1ED; // 0755
    archive.addFile(file);
  }

  add('bin/redis-server', '#!/bin/sh\nexit 0\n'.codeUnits, executable: true);
  add('bin/redis-cli', '#!/bin/sh\nexit 0\n'.codeUnits, executable: true);
  add('bin/redis-benchmark', '#!/bin/sh\nexit 0\n'.codeUnits, executable: true);
  add('manifest.json', '{"schema_version":1}'.codeUnits);

  return GZipEncoder().encode(TarEncoder().encode(archive));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory parent;

  setUp(() {
    parent = Directory.systemTemp.createTempSync('redis_bundle_setup_');
    AppConfig.initialize(baseDir: p.join(parent.path, 'app data'));
  });

  tearDown(() => parent.deleteSync(recursive: true));

  test(
    'installing a portable Redis bundle creates the config redis-server is started with',
    () async {
      const name = 'redis-8.10.3-musl-x86_64-abcdef0123456789';
      final url =
          'https://github.com/ngotuananh101/devstack-app-builder/'
          'releases/download/runtimes-2026-11-06/$name.tar.gz';
      final dio = Dio()
        ..httpClientAdapter = _BundleAdapter(redisBundleArchive(name), url);
      final service = AppInstallerService(LogService(), testRef(), dio: dio);

      final app = AppModel(
        appId: 'redis',
        name: 'Redis',
        categories: const ['database'],
        groupName: 'redis',
        execFile: 'redis-server',
        cliFile: 'redis-cli',
        versionLinksJson: '{"8.10.3":"$url"}',
      );

      final logs = <String>[];
      final installPath = await service.install(app, '8.10.3', onLog: logs.add);

      expect(
        File(p.join(installPath, 'bin', 'redis-server')).existsSync(),
        isTrue,
      );
      expect(app.execFilePath, p.join(installPath, 'bin', 'redis-server'));
      expect(app.cliFilePath, p.join(installPath, 'bin', 'redis-cli'));

      // `redis-server` is started with this file; without it the service
      // exits immediately with "Can't open the configuration file".
      final conf = File(p.join(AppConfig.dataDir, 'redis', 'redis.conf'));
      expect(
        conf.existsSync(),
        isTrue,
        reason: 'Installing Redis must generate the config it is launched with',
      );
      final content = conf.readAsStringSync();
      expect(content, contains('daemonize no'));
      expect(content, contains('port 6379'));
    },
    skip: !Platform.isLinux
        ? 'The portable Redis bundle targets Linux only'
        : false,
  );
}
