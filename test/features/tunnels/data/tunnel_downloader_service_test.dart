import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dev_stack/features/tunnels/data/tunnel_downloader_service.dart';

/// A [HttpClientAdapter] whose response never completes on its own: the
/// request only resolves once the caller cancels the [CancelToken] passed to
/// Dio, at which point it throws a cancellation [DioException]. This lets the
/// test observe that `downloadBinary` honours a cancel token without touching
/// the network.
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
  late Directory tempDir;
  late TunnelDownloaderService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tunnel_downloader_test_');
    service = TunnelDownloaderService(
      baseDirResolver: () => tempDir.path,
      isWindowsResolver: () => true,
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('reports binary not downloaded initially', () async {
    final downloaded = await service.isBinaryDownloaded('cloudflare');
    expect(downloaded, isFalse);
  });

  test('resolves binary path inside tunnels folder', () {
    final path = service.getBinaryPath('cloudflare');
    expect(path, contains('tunnels'));
    expect(path, endsWith('cloudflared.exe'));
  });

  test('reports binary downloaded when file exists and is non-empty', () async {
    final binPath = service.getBinaryPath('cloudflare');
    final file = File(binPath);
    await file.parent.create(recursive: true);
    await file.writeAsString('mock binary content');

    final downloaded = await service.isBinaryDownloaded('cloudflare');
    expect(downloaded, isTrue);
  });

  test('cancelling the token aborts an in-flight download', () async {
    final adapter = _CancelAwareAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final token = CancelToken();

    final future = service.downloadBinary(
      'cloudflare',
      dio: dio,
      cancelToken: token,
    );

    await adapter.started.future;
    token.cancel();

    await expectLater(
      future,
      throwsA(
        isA<DioException>().having(
          (e) => e.type,
          'type',
          DioExceptionType.cancel,
        ),
      ),
    );
  });

  test('a cancelled download leaves no temp file behind', () async {
    final adapter = _CancelAwareAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final token = CancelToken();

    final future = service.downloadBinary(
      'cloudflare',
      dio: dio,
      cancelToken: token,
    );

    await adapter.started.future;
    token.cancel();
    await future.catchError((_) {});

    final tempFile = File('${service.tunnelsDir}/cloudflare.download');
    expect(await tempFile.exists(), isFalse);
  });
}
