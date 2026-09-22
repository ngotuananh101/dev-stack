import 'package:dev_stack/features/tunnels/data/tunnel_downloader_service.dart';
import 'package:dev_stack/features/tunnels/data/tunnel_manager_service.dart';
import 'package:dev_stack/features/tunnels/data/tunnels_provider.dart';
import 'package:dev_stack/features/tunnels/domain/tunnel_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reports the binary as already present so [TunnelManagerService.startTunnel]
/// skips the download step.
class _FakeDownloader extends TunnelDownloaderService {
  _FakeDownloader()
      : super(baseDirResolver: () => '', isWindowsResolver: () => true);

  @override
  Future<bool> isBinaryDownloaded(String provider) async => true;

  @override
  String getBinaryPath(String provider) => 'fake_binary';
}

void main() {
  test('build() seeds from currentSessions and then follows sessionsStream',
      () async {
    final manager = TunnelManagerService(
      downloader: _FakeDownloader(),
      startProcessFn: (exec, args) async => FakeManagedProcess(0),
      stopProcessFn: (pid) async {},
    );
    addTearDown(manager.dispose);

    final container = ProviderContainer.test(
      overrides: [tunnelManagerServiceProvider.overrideWithValue(manager)],
    );

    // Nothing has started yet.
    expect(container.read(tunnelSessionsProvider), isEmpty);

    await manager.startTunnel(
      TunnelModel(
        id: 1,
        name: 'quick',
        provider: 'cloudflare',
        targetPort: 8080,
      ),
    );
    await container.pump();

    // The broadcast stream does not replay, so this only holds if build()
    // both seeded from currentSessions and subscribed before the emit.
    expect(container.read(tunnelSessionsProvider), contains(1));
  });
}
