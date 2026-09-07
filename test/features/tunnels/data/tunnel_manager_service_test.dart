import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:dev_stack/features/tunnels/domain/tunnel_model.dart';
import 'package:dev_stack/features/tunnels/domain/tunnel_session.dart';
import 'package:dev_stack/features/tunnels/data/tunnel_manager_service.dart';
import 'package:dev_stack/features/tunnels/data/tunnel_downloader_service.dart';

class FakeDownloader extends TunnelDownloaderService {
  bool downloaded = true;

  FakeDownloader() : super(baseDirResolver: () => '', isWindowsResolver: () => true);

  @override
  Future<bool> isBinaryDownloaded(String provider) async => downloaded;

  @override
  String getBinaryPath(String provider) => 'fake_binary';

  @override
  Future<void> downloadBinary(String provider, {void Function(double progress)? onProgress, Dio? dio}) async {
    onProgress?.call(0.5);
    onProgress?.call(1.0);
    downloaded = true;
  }
}

void main() {
  late FakeDownloader downloader;
  late FakeManagedProcess fakeProcess;
  late TunnelManagerService manager;

  setUp(() {
    downloader = FakeDownloader();
    fakeProcess = FakeManagedProcess(1234);
    manager = TunnelManagerService(
      downloader: downloader,
      startProcessFn: (exec, args) async => fakeProcess,
      stopProcessFn: (pid) async {},
    );
  });

  tearDown(() async {
    await manager.dispose();
  });

  test('registers session and tracks state transitions', () async {
    final tunnel = TunnelModel(id: 1, name: 'Test Tunnel', targetPort: 80);

    await manager.startTunnel(tunnel);
    final session = manager.getSession(1);
    expect(session, isNotNull);
    expect(session!.status, equals(TunnelStatus.connecting));
    expect(session.pid, equals(1234));

    await manager.stopTunnel(1);
    final stoppedSession = manager.getSession(1);
    expect(stoppedSession?.status, equals(TunnelStatus.stopped));
  });

  test('transitions from connecting to running when Cloudflare emits public URL to stderr', () async {
    final tunnel = TunnelModel(
      id: 2,
      name: 'Cloudflare Tunnel',
      provider: 'cloudflare',
      targetPort: 80,
    );

    await manager.startTunnel(tunnel);
    expect(manager.getSession(2)?.status, equals(TunnelStatus.connecting));
    expect(manager.getSession(2)?.publicUrl, isNull);

    // Simulate Cloudflare stderr output containing public URL
    const logLine = '2026-09-08T00:00:00Z INF |  https://purple-butterfly-123.trycloudflare.com  |\n';
    fakeProcess.stderrController.add(utf8.encode(logLine));

    await Future<void>.delayed(const Duration(milliseconds: 50));

    final runningSession = manager.getSession(2);
    expect(runningSession?.status, equals(TunnelStatus.running));
    expect(runningSession?.publicUrl, equals('https://purple-butterfly-123.trycloudflare.com'));
  });

  test('transitions from connecting to running when ngrok emits JSON log to stdout', () async {
    final tunnel = TunnelModel(
      id: 3,
      name: 'Ngrok Tunnel',
      provider: 'ngrok',
      targetPort: 3000,
    );

    await manager.startTunnel(tunnel);
    expect(manager.getSession(3)?.status, equals(TunnelStatus.connecting));

    // Simulate ngrok stdout output containing public URL and inspector
    const jsonLine = '{"lvl":"info","msg":"started tunnel","url":"https://abc.ngrok-free.app"}\n';
    const inspectorLine = '{"lvl":"info","msg":"starting web service","addr":"127.0.0.1:4040"}\n';
    fakeProcess.stdoutController.add(utf8.encode(jsonLine));
    fakeProcess.stdoutController.add(utf8.encode(inspectorLine));

    await Future<void>.delayed(const Duration(milliseconds: 50));

    final runningSession = manager.getSession(3);
    expect(runningSession?.status, equals(TunnelStatus.running));
    expect(runningSession?.publicUrl, equals('https://abc.ngrok-free.app'));
    expect(runningSession?.webInspectorUrl, equals('http://127.0.0.1:4040'));
  });
}
