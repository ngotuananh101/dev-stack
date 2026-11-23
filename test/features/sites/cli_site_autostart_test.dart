import 'dart:io';

import 'package:dev_stack/core/database/isar_provider.dart';
import 'package:dev_stack/core/services/log_service.dart';
import 'package:dev_stack/features/sites/data/cli_process_manager.dart';
import 'package:dev_stack/features/sites/data/cli_site_autostart.dart';
import 'package:dev_stack/features/sites/data/sites_provider.dart';
import 'package:dev_stack/features/sites/domain/site_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

String? _isarLibraryPath() {
  final libName = Platform.isWindows
      ? 'isar_plus.dll'
      : (Platform.isLinux ? 'libisar_plus.so' : null);
  if (libName == null) return null;

  final pubCache =
      Platform.environment['PUB_CACHE'] ??
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

class _FakeCliProcessManager extends CliProcessManager {
  final List<int> startedIds = [];
  final Map<int, Object> failures = {};

  @override
  Future<bool> startSite(SiteModel site) async {
    final failure = failures[site.id];
    if (failure != null) throw failure;
    startedIds.add(site.id);
    return true;
  }
}

void main() {
  final libraryPath = _isarLibraryPath();

  late Isar isar;
  late Directory tempDir;
  late LogService logger;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('cli_autostart_test_');
    addTearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    Isar.initialize(libraryPath);
    isar = Isar.open(
      schemas: [SiteModelSchema],
      directory: tempDir.path,
      name: 'cli_autostart_${DateTime.now().microsecondsSinceEpoch}',
    );
    addTearDown(isar.close);

    logger = LogService(logDir: tempDir.path);
  });

  void seed(List<SiteModel> sites) {
    isar.write((_) {
      isar.siteModels.putAll(sites);
    });
  }

  SiteModel site({
    required int id,
    required String domain,
    String siteType = 'cli',
    bool autoStart = true,
    String? command = 'npm run dev',
    int port = 8001,
  }) => SiteModel(
    id: id,
    domain: domain,
    rootDir: tempDir.path,
    siteType: siteType,
    command: siteType == 'cli' ? command : null,
    port: siteType == 'cli' ? port : null,
    autoStart: autoStart,
  );

  group(
    'startAutoStartCliSites',
    () {
      test('starts only CLI sites flagged for auto-start', () async {
        seed([
          site(id: 1, domain: 'vue.test'),
          site(id: 2, domain: 'manual.test', autoStart: false),
          site(id: 3, domain: 'php.test', siteType: 'php'),
        ]);
        final manager = _FakeCliProcessManager();

        await startAutoStartCliSites(
          isar: isar,
          manager: manager,
          logger: logger,
        );

        expect(manager.startedIds, [1]);
      });

      test('a failing site does not prevent the remaining ones', () async {
        seed([
          site(id: 1, domain: 'broken.test'),
          site(id: 2, domain: 'vue.test'),
        ]);
        final manager = _FakeCliProcessManager()
          ..failures[1] = StateError('Root directory does not exist');

        await startAutoStartCliSites(
          isar: isar,
          manager: manager,
          logger: logger,
        );

        expect(manager.startedIds, [2]);
      });

      test('skips a CLI site with an empty command instead of throwing', () async {
        seed([
          site(id: 1, domain: 'empty.test', command: '   '),
          site(id: 2, domain: 'vue.test'),
        ]);
        final manager = _FakeCliProcessManager();

        await startAutoStartCliSites(
          isar: isar,
          manager: manager,
          logger: logger,
        );

        expect(manager.startedIds, [2]);
      });

      test(
        'building the autoDispose Sites provider starts nothing',
        () async {
          seed([site(id: 1, domain: 'vue.test')]);
          final manager = _FakeCliProcessManager();
          final container = ProviderContainer.test(
            overrides: [
              isarProvider.overrideWith((ref) async => isar),
              cliProcessManagerProvider.overrideWithValue(manager),
            ],
          );

          // The Sites tab is what builds this provider; auto-start must not
          // ride on it, or a dev server stays down until the tab is opened.
          final sites = await container.read(sitesProvider.future);
          expect(sites.map((s) => s.domain), ['vue.test']);
          await Future<void>.delayed(Duration.zero);

          expect(manager.startedIds, isEmpty);
        },
        skip: libraryPath == null ? 'Isar native library not available' : false,
      );
    },
    skip: libraryPath == null ? 'Isar native library not available' : false,
  );
}
