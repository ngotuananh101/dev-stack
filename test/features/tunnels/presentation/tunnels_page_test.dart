import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dev_stack/features/tunnels/presentation/tunnels_page.dart';
import 'package:dev_stack/features/tunnels/data/tunnels_provider.dart';
import 'package:dev_stack/features/tunnels/data/tunnel_manager_service.dart';
import 'package:dev_stack/features/tunnels/domain/tunnel_model.dart';
import 'package:dev_stack/features/tunnels/domain/tunnel_session.dart';

void main() {
  testWidgets('TunnelsPage renders header and empty state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tunnelsStreamProvider.overrideWith((ref) => Stream.value([])),
          tunnelSessionsProvider.overrideWith(
            (ref) => TunnelSessionsNotifierMock({}),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: TunnelsPage()),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Tunnels'), findsOneWidget);
    expect(find.text('New Tunnel'), findsOneWidget);
    expect(find.text('No tunnels configured yet'), findsOneWidget);
  });

  testWidgets('TunnelsPage displays tunnel card with actions', (tester) async {
    final mockTunnel = TunnelModel(
      id: 10,
      name: 'Shopify Webhook',
      provider: 'cloudflare',
      targetPort: 80,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tunnelsStreamProvider.overrideWith((ref) => Stream.value([mockTunnel])),
          tunnelSessionsProvider.overrideWith(
            (ref) => TunnelSessionsNotifierMock({
              10: const TunnelSession(
                tunnelId: 10,
                status: TunnelStatus.running,
                publicUrl: 'https://myshop.trycloudflare.com',
              ),
            }),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: TunnelsPage()),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Shopify Webhook'), findsOneWidget);
    expect(find.text('https://myshop.trycloudflare.com'), findsOneWidget);
  });
}

/// Minimal TunnelSessionsNotifier subclass for tests. The base class wires up a
/// sessionsStream subscription on the provided TunnelManagerService, so we pass
/// one configured with no-op process callbacks to avoid spawning subprocesses.
/// The desired initial sessions are written to [state] after the super
/// constructor installs the (idle) stream listener.
class TunnelSessionsNotifierMock extends TunnelSessionsNotifier {
  TunnelSessionsNotifierMock(Map<int, TunnelSession> initial)
      : super(
          TunnelManagerService(
            startProcessFn: (exec, args) async => FakeManagedProcess(0),
            stopProcessFn: (pid) async {},
          ),
        ) {
    state = initial;
  }
}
