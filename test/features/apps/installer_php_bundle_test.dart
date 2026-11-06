import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:dev_stack/core/config/app_config.dart';
import 'package:dev_stack/core/services/log_service.dart';
import 'package:dev_stack/features/apps/data/app_installer_service.dart';
import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import '../../helpers/php_bundle_fixture.dart';
import '../../helpers/test_ref.dart';

class _ArchiveAdapter implements HttpClientAdapter {
  final List<int> bytes;
  _ArchiveAdapter(this.bytes);
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.uri.toString() != 'https://example.test/php.zip') {
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory parent;
  late Directory root;
  late AppInstallerService installer;
  late AppModel app;
  setUp(() {
    parent = Directory.systemTemp.createTempSync('php_setup_');
    root = createPhpBundleFixture(parent);
    AppConfig.initialize(baseDir: p.join(parent.path, 'app data'));
    installer = AppInstallerService(LogService(), testRef());
    app = AppModel(
      appId: 'php84',
      name: 'PHP 8.4',
      categories: ['runtime'],
      groupName: 'php',
      execFile: 'php-fpm',
      cliFile: 'php',
    );
  });
  tearDown(() => parent.deleteSync(recursive: true));
  test(
    'bundle setup selects launchers, preserves extension settings and creates FPM config',
    () async {
      await installer.configurePhpBundle(app, root.path, '8.4.27', (_) {});
      expect(app.cliFilePath, p.join(root.path, 'bin/php'));
      expect(app.execFilePath, p.join(root.path, 'bin/php-fpm'));
      final ini = File(p.join(root.path, 'etc/php.ini')).readAsStringSync();
      expect(ini, contains('memory_limit = 2G'));
      expect(ini, isNot(contains('extension_dir = "ext"')));
      expect(ini, isNot(contains('extension=')));
      expect(Directory(AppConfig.logsDir).existsSync(), isTrue);
      final config = File(
        p.join(AppConfig.baseDir, 'php/php84/php-fpm.conf'),
      ).readAsStringSync();
      expect(config, contains('listen = 127.0.0.1:9084'));
      expect(
        config,
        contains('error_log = "${AppConfig.logsDir}/php84-fpm.error.log"'),
      );
      for (final path in [
        'bin/php',
        'bin/php-fpm',
        'bin/php-ext',
        'libexec/php',
        'libexec/php-fpm',
      ]) {
        expect(File(p.join(root.path, path)).statSync().mode & 0x49, isNot(0));
      }
    },
  );
  test('setup preserves existing caller-owned FPM config', () async {
    final file = File(p.join(AppConfig.baseDir, 'php/php84/php-fpm.conf'));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync('user config');
    await installer.configurePhpBundle(app, root.path, '8.4.27', (_) {});
    expect(file.readAsStringSync(), 'user config');
  });
  test(
    'standard archive pipeline fails setup before reporting completion',
    () async {
      editBundleManifest(root, (m) => m['php']['version'] = '8.4.26');
      final archive = Archive();
      for (final file in root.listSync(recursive: true).whereType<File>()) {
        final bytes = file.readAsBytesSync();
        archive.addFile(
          ArchiveFile(
            'bundle/${p.relative(file.path, from: root.path)}',
            bytes.length,
            bytes,
          ),
        );
      }
      // Empty scan directories must survive extraction.
      for (final dir in ['etc/cli/conf.d', 'etc/fpm/conf.d']) {
        archive.addFile(ArchiveFile('bundle/$dir/.keep', 0, <int>[]));
      }
      final dio = Dio()
        ..httpClientAdapter = _ArchiveAdapter(ZipEncoder().encode(archive));
      final service = AppInstallerService(LogService(), testRef(), dio: dio);
      app.versionLinks = {'8.4.27': 'https://example.test/php.zip'};
      final logs = <String>[];
      await expectLater(
        service.install(app, '8.4.27', onLog: logs.add),
        throwsFormatException,
      );
      expect(
        logs.any((line) => line.startsWith('Successfully installed')),
        isFalse,
      );
      expect(app.cliFilePath, isNull);
    },
  );

  test(
    'wrong version fails before recording launchers or creating config',
    () async {
      await expectLater(
        installer.configurePhpBundle(app, root.path, '8.4.26', (_) {}),
        throwsFormatException,
      );
      expect(app.cliFilePath, isNull);
      expect(Directory(p.join(AppConfig.baseDir, 'php')).existsSync(), isFalse);
    },
  );
}
