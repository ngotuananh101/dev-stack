import 'dart:io';

import 'package:dev_stack/core/config/app_config.dart';
import 'package:dev_stack/core/services/log_service.dart';
import 'package:dev_stack/core/services/path_service.dart';
import 'package:dev_stack/features/apps/data/app_installer_service.dart';
import 'package:dev_stack/features/apps/data/app_service_manager.dart';
import 'package:dev_stack/features/apps/data/apps_provider.dart';
import 'package:dev_stack/features/apps/data/apps_repository.dart';
import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../helpers/test_ref.dart';

/// Records the environment edits instead of touching the real user profile.
class _RecordingPathService extends PathService {
  _RecordingPathService() : super(LogService());

  final removedVars = <String>[];
  final removedDirs = <String>[];

  @override
  Future<void> removeUserEnvVar(String name) async => removedVars.add(name);

  @override
  Future<void> removeUserEnvVarValue(String name, String value) async =>
      removedVars.add(name);

  @override
  Future<void> removeRawPathFromUserPath(String pathToRemove) async =>
      removedDirs.add(pathToRemove);
}

class _Repository implements AppsRepository {
  final List<AppModel> apps;
  _Repository(this.apps);

  @override
  Future<List<AppModel>> getAll() async => apps;

  @override
  Future<void> delete(String appId) async =>
      apps.removeWhere((app) => app.appId == appId);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Keeps the uninstall flow off the real filesystem. Everything else runs for
/// real, so the per-app rules in [AppInstallerService.cleanupSdkRuntime] are
/// the code under test rather than a copy of them.
class _RecordingInstaller extends AppInstallerService {
  _RecordingInstaller(ProviderContainer container)
    : super(LogService(), testRef(container));

  final deleted = <(String, String)>[];

  /// Set to make [delete] fail the way a locked file does on Windows.
  Object? deleteError;

  @override
  Future<void> delete(
    String path,
    String appId,
    String? version, {
    bool deleteData = true,
  }) async {
    if (deleteError != null) throw deleteError!;
    deleted.add((path, appId));
  }
}

class _Services extends AppServiceManager {
  _Services() : super(LogService(), runProcess: (exe, args) async => []);

  @override
  void syncAppState(AppModel app) {}

  @override
  bool isRunning(String appId) => false;

  @override
  Future<void> forceKillPid(
    String appId,
    int pid, {
    Future<ProcessResult> Function(String, List<String>)? runProcess,
    bool? isWindows,
  }) async {}
}

void main() {
  group('AppInstallerService.cleanupSdkRuntime', () {
    late Directory tempDir;
    late ProviderContainer container;
    late _RecordingPathService paths;
    late List<String> logs;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('sdk_cleanup_test_');
      paths = _RecordingPathService();
      logs = [];
      container = ProviderContainer.test(
        overrides: [pathServiceProvider.overrideWithValue(paths)],
      );
    });

    tearDown(() {
      container.dispose();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    Future<void> cleanup(String appId) {
      final installer = AppInstallerService(LogService(), testRef(container));
      return installer.cleanupSdkRuntime(
        appId: appId,
        installPath: tempDir.path,
        logInfo: logs.add,
      );
    }

    test('Go loses GOROOT and its bin/ from PATH', () async {
      await cleanup('go');

      expect(paths.removedVars, ['GOROOT']);
      expect(paths.removedDirs, [p.join(tempDir.path, 'bin')]);
      expect(
        logs.join('\n'),
        contains('GOROOT'),
        reason: 'the log must say what was removed',
      );
    });

    test('Java loses JAVA_HOME and its bin/ from PATH', () async {
      await cleanup('java');

      expect(paths.removedVars, ['JAVA_HOME']);
      expect(paths.removedDirs, [p.join(tempDir.path, 'bin')]);
    });

    test('Flutter has no variable to remove, only its PATH entry', () async {
      await cleanup('flutter');

      expect(paths.removedVars, isEmpty);
      expect(paths.removedDirs, [p.join(tempDir.path, 'bin')]);
    });

    test('runtimes that wire nothing are left alone', () async {
      await cleanup('nodejs');
      await cleanup('php84');

      expect(paths.removedVars, isEmpty);
      expect(paths.removedDirs, isEmpty);
      expect(logs, isEmpty);
    });
  });

  group('uninstall', () {
    late Directory root;
    late ProviderContainer container;
    late _Repository repository;
    late _RecordingPathService paths;
    late _RecordingInstaller installer;

    setUp(() {
      root = Directory.systemTemp.createTempSync('sdk_uninstall_test_');
      AppConfig.initialize(baseDir: root.path);
      paths = _RecordingPathService();
      repository = _Repository([]);
      container = ProviderContainer.test(
        overrides: [
          appsRepositoryProvider.overrideWith((ref) async => repository),
          appInstallerServiceProvider.overrideWith(
            (ref) => installer = _RecordingInstaller(container),
          ),
          appServiceManagerProvider.overrideWithValue(_Services()),
          pathServiceProvider.overrideWithValue(paths),
        ],
      );
      // Build the fake up front so a test can arm it before `uninstall` runs.
      installer = container.read<AppInstallerService>(
        appInstallerServiceProvider,
      ) as _RecordingInstaller;
    });

    tearDown(() {
      container.dispose();
      AppConfig.initialize(baseDir: AppConfig.defaultBaseDir);
      root.deleteSync(recursive: true);
    });

    Future<void> uninstall(AppModel app) async {
      repository.apps.add(app);
      await container.read(appsProvider.future);
      await container.read(appsProvider.notifier).uninstall(app);
    }

    test('uninstall removes the SDK wiring, not just the directory', () async {
      final install = Directory(p.join(root.path, 'apps/java/21.0.13'))
        ..createSync(recursive: true);
      final app = AppModel(
        appId: 'java',
        name: 'Java',
        categories: ['runtime'],
        isInstalled: true,
        installedVersion: '21.0.13',
        status: 'installed',
      )..location = install.path;

      await uninstall(app);

      expect(app.isInstalled, isFalse);
      expect(
        paths.removedVars,
        ['JAVA_HOME'],
        reason: 'a JAVA_HOME left pointing at a deleted directory breaks Gradle',
      );
      expect(paths.removedDirs, [p.join(install.path, 'bin')]);
    });

    test('uninstall leaves the environment of an app that wires nothing', () async {
      final install = Directory(p.join(root.path, 'apps/php84/8.4.27'))
        ..createSync(recursive: true);
      final app = AppModel(
        appId: 'php84',
        name: 'PHP 8.4',
        categories: ['runtime'],
        isInstalled: true,
        installedVersion: '8.4.27',
        status: 'installed',
      )..location = install.path;

      await uninstall(app);

      expect(paths.removedVars, isEmpty);
      expect(paths.removedDirs, isEmpty);
    });

    test('a failed delete keeps the environment wired', () async {
      // Windows refuses to delete a directory whose binary is still running.
      // Clearing JAVA_HOME first would leave an installed, listed app that no
      // longer starts — worse than the leftovers this cleanup removes.
      final install = Directory(p.join(root.path, 'apps/java/21.0.13'))
        ..createSync(recursive: true);
      final app = AppModel(
        appId: 'java',
        name: 'Java',
        categories: ['runtime'],
        isInstalled: true,
        installedVersion: '21.0.13',
        status: 'installed',
      )..location = install.path;
      repository.apps.add(app);
      await container.read(appsProvider.future);
      installer.deleteError = const FileSystemException('in use');
      await container.read(appsProvider.notifier).uninstall(app);

      expect(paths.removedVars, isEmpty);
      expect(paths.removedDirs, isEmpty);
    });
  });
}
