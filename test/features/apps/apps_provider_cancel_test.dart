import 'dart:async';
import 'dart:io';

import 'package:dev_stack/core/services/log_service.dart';
import 'package:dev_stack/features/apps/data/app_installer_service.dart';
import 'package:dev_stack/features/apps/data/app_service_manager.dart';
import 'package:dev_stack/features/apps/data/apps_provider.dart';
import 'package:dev_stack/features/apps/data/apps_repository.dart';
import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_ref.dart';

/// In-memory repository so the notifier can load/save without Isar.
class _FakeRepository implements AppsRepository {
  final List<AppModel> apps;

  _FakeRepository(this.apps);

  @override
  Future<List<AppModel>> getAll() async => apps;

  @override
  Future<void> save(AppModel app) async {}

  @override
  Future<void> setDefaultPhp(String appId) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// An installer whose [install] blocks until the cancel token is cancelled,
/// then throws [InstallationCancelledException] — mirroring the real service.
class _BlockingInstaller extends AppInstallerService {
  _BlockingInstaller() : super(LogService(), testRef());

  @override
  Future<String> install(
    AppModel app,
    String version, {
    InstallationProgressCallback? onProgress,
    InstallationLogCallback? onLog,
    Future<ProcessResult> Function(String, List<String>)? runProcess,
    CancelToken? cancelToken,
  }) async {
    onProgress?.call(0.1, 'Downloading...');
    final cancelled = Completer<void>();
    cancelToken?.whenCancel.then((_) {
      if (!cancelled.isCompleted) cancelled.complete();
    });
    await cancelled.future;
    throw InstallationCancelledException();
  }
}

void main() {
  late AppModel app;
  late ProviderContainer container;

  setUp(() {
    app = AppModel(
      appId: 'testapp',
      name: 'Test App',
      categories: const ['tools'],
      versions: const ['latest', '1.0.0'],
      selectedVersion: '1.0.0',
    );

    container = ProviderContainer.test(
      overrides: [
        appsRepositoryProvider.overrideWith(
          (ref) async => _FakeRepository([app]),
        ),
        appInstallerServiceProvider.overrideWithValue(_BlockingInstaller()),
        appServiceManagerProvider.overrideWithValue(
          AppServiceManager(LogService()),
        ),
      ],
    );
  });

  tearDown(() => container.dispose());

  test('cancelInstall aborts an in-flight install and resets the app', () async {
    final notifier = container.read(appsProvider.notifier);
    // Kick off the install; it blocks inside the fake installer.
    final installFuture = notifier.toggleInstallation(app);
    await Future<void>.delayed(Duration.zero);

    expect(app.status, 'installing');

    final cancelled = notifier.cancelInstall('testapp');
    expect(cancelled, isTrue);

    await installFuture;

    expect(app.status, 'not_installed');
    expect(app.installProgress, isNull);
    expect(app.isInstalled, isFalse);
  });

  test('cancelInstall returns false when nothing is installing', () {
    final notifier = container.read(appsProvider.notifier);
    expect(notifier.cancelInstall('testapp'), isFalse);
  });
}
