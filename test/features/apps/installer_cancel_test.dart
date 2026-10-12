import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dev_stack/core/config/app_config.dart';
import 'package:dev_stack/core/services/log_service.dart';
import 'package:dev_stack/features/apps/data/app_installer_service.dart';
import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_ref.dart';

/// A [HttpClientAdapter] whose response never completes on its own: the request
/// only resolves once the caller cancels the [CancelToken] passed to Dio, at
/// which point it throws a cancellation [DioException]. Lets a test observe
/// that `install` honours a cancel token without touching the network.
class _CancelAwareAdapter implements HttpClientAdapter {
  final Completer<void> started = Completer<void>();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (!started.isCompleted) started.complete();

    final cancelled = Completer<void>();
    cancelFuture?.then((_) {
      if (!cancelled.isCompleted) cancelled.complete();
    });
    await cancelled.future;

    throw DioException(
      requestOptions: options,
      type: DioExceptionType.cancel,
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late AppInstallerService installer;

  setUp(() {
    AppConfig.initialize(
      baseDir: Directory.systemTemp.createTempSync('ponta_cancel_test_').path,
    );
    installer = AppInstallerService(LogService(), testRef());
  });

  test('cancelling during download aborts with InstallationCancelledException',
      () async {
    final adapter = _CancelAwareAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final service = AppInstallerService(LogService(), testRef(), dio: dio);

    final app = AppModel(
      appId: 'testapp',
      name: 'Test App',
      categories: const ['tools'],
      versionLinksJson: '{"1.0.0":"https://example.com/testapp.tar.gz"}',
    );
    final token = CancelToken();

    final future = service.install(app, '1.0.0', cancelToken: token);

    await adapter.started.future;
    token.cancel();

    await expectLater(
      future,
      throwsA(isA<InstallationCancelledException>()),
    );
  });

  test('install completes without a cancel token (no regression)', () async {
    // A missing URL is a plain failure, not a cancellation — it must still be
    // reported as a normal error rather than swallowed.
    final app = AppModel(
      appId: 'testapp',
      name: 'Test App',
      categories: const ['tools'],
    );

    await expectLater(
      installer.install(app, '1.0.0'),
      throwsA(isNot(isA<InstallationCancelledException>())),
    );
  });
}
