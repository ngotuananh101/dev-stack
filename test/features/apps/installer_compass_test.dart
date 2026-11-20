import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:dev_stack/core/config/app_config.dart';
import 'package:dev_stack/core/services/log_service.dart';
import 'package:dev_stack/features/apps/data/app_installer_service.dart';
import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../helpers/test_ref.dart';

class _ArchiveAdapter implements HttpClientAdapter {
  final List<int> bytes;
  _ArchiveAdapter(this.bytes);
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromBytes(
    bytes,
    200,
    headers: {
      Headers.contentLengthHeader: ['${bytes.length}'],
    },
  );
  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late AppInstallerService installer;
  setUp(() {
    root = Directory.systemTemp.createTempSync('compass_installer_');
    AppConfig.initialize(baseDir: root.path);
    installer = AppInstallerService(LogService(), testRef());
  });
  tearDown(() {
    root.deleteSync(recursive: true);
  });

  for (final id in ['mongodb-compass', 'mongodb']) {
    test('uninstall $id only deletes MongoDB data when it owns it', () async {
      final data = File(p.join(AppConfig.dataDir, 'mongodb', 'sentinel'))
        ..createSync(recursive: true);
      data.writeAsStringSync('server data');
      final install = Directory(p.join(AppConfig.appsDir, id, '1.53.2'))
        ..createSync(recursive: true);
      await installer.delete(install.path, id, '1.53.2');
      expect(install.existsSync(), isFalse);
      expect(data.existsSync(), id != 'mongodb');
      if (id != 'mongodb') expect(data.readAsStringSync(), 'server data');
    });
  }

  Future<String> installArchive({
    bool mainExecutable = true,
    bool badHash = false,
  }) async {
    final archive = Archive();
    for (final name in [
      if (mainExecutable) 'MongoDB Compass',
      'chrome_crashpad_handler',
      'chrome-sandbox',
      'resources/app.asar',
    ]) {
      final file = ArchiveFile('MongoDB Compass-linux-x64/$name', 4, [
        1,
        2,
        3,
        4,
      ]);
      file.mode = name.startsWith('resources/') ? 0x1a4 : 0x1ed;
      archive.addFile(file);
    }
    final bytes = GZipEncoder().encode(TarEncoder().encode(archive));
    final app = AppModel(
      appId: 'mongodb-compass',
      name: 'MongoDB Compass',
      categories: ['tool'],
      execFile: 'MongoDB Compass',
      versionLinksJson: jsonEncode({
        '1.53.2': 'https://example.test/compass.tar.gz',
      }),
      versionSha256Json: jsonEncode({
        '1.53.2': badHash ? '0' * 64 : sha256.convert(bytes).toString(),
      }),
    );
    final service = AppInstallerService(
      LogService(),
      testRef(),
      dio: Dio()..httpClientAdapter = _ArchiveAdapter(bytes),
    );
    final path = await service.install(app, '1.53.2');
    if (mainExecutable) {
      expect(app.execFilePath, p.join(path, 'MongoDB Compass'));
    }
    expect(app.cliFilePath, isNull);
    return path;
  }

  test(
    'installs the full Compass tree and retains helper executable modes',
    () async {
      final path = await installArchive();
      expect(File(p.join(path, 'resources', 'app.asar')).readAsBytesSync(), [
        1,
        2,
        3,
        4,
      ]);
      if (Platform.isLinux) {
        for (final file in [
          'MongoDB Compass',
          'chrome_crashpad_handler',
          'chrome-sandbox',
        ]) {
          expect(File(p.join(path, file)).statSync().mode & 0x40, isNonZero);
        }
      }
    },
  );
  test(
    'does not report success if the Compass executable is missing',
    () async {
      await expectLater(
        installArchive(mainExecutable: false),
        throwsA(
          predicate(
            (e) => e.toString().contains('Compass executable not found'),
          ),
        ),
      );
    },
    skip: Platform.isLinux ? false : 'Requires Linux Compass installation',
  );
  test('checksum mismatch prevents extracting Compass', () async {
    await expectLater(
      installArchive(badHash: true),
      throwsA(isA<ChecksumMismatchException>()),
    );
    expect(
      File(
        p.join(
          AppConfig.appsDir,
          'mongodb-compass',
          '1.53.2',
          'MongoDB Compass',
        ),
      ).existsSync(),
      isFalse,
    );
  });
}
