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
  late TunnelManagerService manager;

  setUp(() {
    downloader = FakeDownloader();
    manager = TunnelManagerService(
      downloader: downloader,
      startProcessFn: (exec, args) async {
        return FakeManagedProcess(1234);
      },
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
}
