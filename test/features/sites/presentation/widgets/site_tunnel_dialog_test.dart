import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dev_stack/features/sites/domain/site_model.dart';
import 'package:dev_stack/features/sites/presentation/widgets/site_tunnel_dialog.dart';
import 'package:dev_stack/features/tunnels/data/tunnels_provider.dart';
import 'package:dev_stack/features/tunnels/data/tunnel_downloader_service.dart';
import 'package:dev_stack/features/tunnels/data/tunnel_manager_service.dart';
import 'package:dev_stack/features/tunnels/domain/tunnel_model.dart';
import 'package:dev_stack/features/tunnels/domain/tunnel_session.dart';

/// A fake downloader that reports the binary as already downloaded, so
/// [TunnelManagerService.startTunnel] skips the download step in tests.
class _FakeDownloader extends TunnelDownloaderService {
  _FakeDownloader() : super(baseDirResolver: () => '', isWindowsResolver: () => true);

  @override
  Future<bool> isBinaryDownloaded(String provider) async => true;

  @override
  String getBinaryPath(String provider) => 'fake_binary';
}

/// A minimal host screen that shows SiteTunnelDialog via showDialog, so that
/// Navigator.pop inside the dialog works correctly during tests.
class _HostScreen extends ConsumerWidget {
  final SiteModel site;

  const _HostScreen({required this.site});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => SiteTunnelDialog(site: site),
            );
          },
          child: const Text('Open Dialog'),
        ),
      ),
    );
  }
}

Future<void> _openDialog(WidgetTester tester) async {
  await tester.tap(find.text('Open Dialog'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('SiteTunnelDialog shows quick tunnel options when no tunnel configured', (tester) async {
    final site = SiteModel(
      domain: 'myproject.test',
      rootDir: '/var/www/myproject',
      phpPort: 9000,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tunnelsStreamProvider.overrideWith((ref) => Stream.value([])),
          tunnelSessionsProvider.overrideWith(
            (ref) => TunnelSessionsNotifierMock({}),
          ),
        ],
        child: MaterialApp(
          home: _HostScreen(site: site),
        ),
      ),
    );

    await _openDialog(tester);
    expect(find.text('Share myproject.test'), findsOneWidget);
    expect(find.text('Start Quick Tunnel (Cloudflare)'), findsOneWidget);
    expect(find.text('Configure Tunnel'), findsOneWidget);
  });

  testWidgets('SiteTunnelDialog shows running tunnel status and public URL', (tester) async {
    final site = SiteModel(
      domain: 'myproject.test',
      rootDir: '/var/www/myproject',
    );

    final tunnel = TunnelModel(
      id: 10,
      name: 'myproject.test',
      provider: 'cloudflare',
      targetType: 'site',
      targetSiteDomain: 'myproject.test',
      targetPort: 9000,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tunnelsStreamProvider.overrideWith((ref) => Stream.value([tunnel])),
          tunnelSessionsProvider.overrideWith(
            (ref) => TunnelSessionsNotifierMock({
              10: const TunnelSession(
                tunnelId: 10,
                status: TunnelStatus.running,
                publicUrl: 'https://myproject.trycloudflare.com',
              ),
            }),
          ),
        ],
        child: MaterialApp(
          home: _HostScreen(site: site),
        ),
      ),
    );

    await _openDialog(tester);
    expect(find.text('Share myproject.test'), findsOneWidget);
    expect(find.text('RUNNING'), findsOneWidget);
    expect(find.text('https://myproject.trycloudflare.com'), findsOneWidget);
  });

  testWidgets('SiteTunnelDialog shows stopped tunnel with start button', (tester) async {
    final site = SiteModel(
      domain: 'myproject.test',
      rootDir: '/var/www/myproject',
    );

    final tunnel = TunnelModel(
      id: 10,
      name: 'myproject.test',
      provider: 'cloudflare',
      targetType: 'site',
      targetSiteDomain: 'myproject.test',
      targetPort: 9000,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tunnelsStreamProvider.overrideWith((ref) => Stream.value([tunnel])),
          tunnelSessionsProvider.overrideWith(
            (ref) => TunnelSessionsNotifierMock({
              10: const TunnelSession(
                tunnelId: 10,
                status: TunnelStatus.stopped,
              ),
            }),
          ),
        ],
        child: MaterialApp(
          home: _HostScreen(site: site),
        ),
      ),
    );

    await _openDialog(tester);
    expect(find.text('Share myproject.test'), findsOneWidget);
    expect(find.text('Start Tunnel'), findsOneWidget);
  });

  testWidgets('SiteTunnelDialog shows not-running state when session is null', (tester) async {
    final site = SiteModel(
      domain: 'myproject.test',
      rootDir: '/var/www/myproject',
    );

    final tunnel = TunnelModel(
      id: 10,
      name: 'myproject.test',
      provider: 'cloudflare',
      targetType: 'site',
      targetSiteDomain: 'myproject.test',
      targetPort: 9000,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tunnelsStreamProvider.overrideWith((ref) => Stream.value([tunnel])),
          tunnelSessionsProvider.overrideWith(
            (ref) => TunnelSessionsNotifierMock({}),
          ),
        ],
        child: MaterialApp(
          home: _HostScreen(site: site),
        ),
      ),
    );

    await _openDialog(tester);
    expect(find.text('Share myproject.test'), findsOneWidget);
    expect(find.text('Start Tunnel'), findsOneWidget);
  });

  testWidgets('SiteTunnelDialog quick tunnel button creates and starts tunnel', (tester) async {
    final site = SiteModel(
      domain: 'myproject.test',
      rootDir: '/var/www/myproject',
      phpPort: 9000,
    );

    final mockManager = TunnelManagerService(
      downloader: _FakeDownloader(),
      startProcessFn: (exec, args) async => FakeManagedProcess(0),
      stopProcessFn: (pid) async {},
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tunnelsStreamProvider.overrideWith((ref) => Stream.value([])),
          tunnelManagerServiceProvider.overrideWithValue(mockManager),
          tunnelSessionsProvider.overrideWith(
            (ref) => TunnelSessionsNotifierMock({}, manager: mockManager),
          ),
        ],
        child: MaterialApp(
          home: _HostScreen(site: site),
        ),
      ),
    );

    await _openDialog(tester);
    await tester.tap(find.text('Start Quick Tunnel (Cloudflare)'));
    await tester.pumpAndSettle();

    // Dialog should close after quick tunnel is created and started
    expect(find.text('Start Quick Tunnel (Cloudflare)'), findsNothing);

    // Verify the tunnel was created in the mock manager
    expect(mockManager.currentSessions, isNotEmpty);
  });
}

/// Minimal TunnelSessionsNotifier subclass for tests. The base class wires up a
/// sessionsStream subscription on the provided TunnelManagerService, so we pass
/// one configured with no-op process callbacks to avoid spawning subprocesses.
/// The desired initial sessions are written to [state] after the super
/// constructor installs the (idle) stream listener.
class TunnelSessionsNotifierMock extends TunnelSessionsNotifier {
  TunnelSessionsNotifierMock(
    Map<int, TunnelSession> initial, {
    TunnelManagerService? manager,
  })  : super(manager ??
            TunnelManagerService(
              downloader: _FakeDownloader(),
              startProcessFn: (exec, args) async => FakeManagedProcess(0),
              stopProcessFn: (pid) async {},
            )) {
    state = initial;
  }
}
