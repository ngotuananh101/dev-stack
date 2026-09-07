import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dev_stack/features/tunnels/data/tunnel_downloader_service.dart';

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
}
