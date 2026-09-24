import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dev_stack/features/tunnels/presentation/tunnels_page.dart';
import 'package:dev_stack/features/tunnels/data/tunnels_provider.dart';
import 'package:dev_stack/features/tunnels/domain/tunnel_model.dart';
import 'package:dev_stack/features/tunnels/domain/tunnel_session.dart';
import 'package:dev_stack/shared/widgets/app_button.dart';

void main() {
  testWidgets('TunnelsPage renders header and empty state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tunnelsStreamProvider.overrideWith((ref) => Stream.value([])),
          tunnelSessionsProvider.overrideWith(
            () => TunnelSessionsNotifierMock({}),
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

    // New Tunnel button is placed on the right side on the same row with the title
    final tunnelsPos = tester.getTopLeft(find.text('Tunnels'));
    final newTunnelPos = tester.getTopLeft(find.widgetWithText(AppButton, 'New Tunnel'));
    expect(newTunnelPos.dx, greaterThan(500.0));
    expect(newTunnelPos.dx, greaterThan(tunnelsPos.dx));
    expect((newTunnelPos.dy - tunnelsPos.dy).abs(), lessThan(35.0));
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
            () => TunnelSessionsNotifierMock({
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

/// Minimal TunnelSessionsNotifier subclass for tests.
///
/// [build] deliberately does not call `super.build()`, so no real
/// [TunnelManagerService] is constructed — these tests only render, and
/// constructing the real manager would drag in the tunnel downloader, the log
/// service, and a real database. The base class's `_manager` is library-private
/// and assigned only inside `build()`, so a subclass in `test/` cannot read or
/// set it; the three actions are overridden instead.
class TunnelSessionsNotifierMock extends TunnelSessionsNotifier {
  TunnelSessionsNotifierMock(this._initial);

  final Map<int, TunnelSession> _initial;

  @override
  Map<int, TunnelSession> build() => _initial;

  @override
  Future<void> start(TunnelModel tunnel) => Future<void>.value();

  @override
  Future<void> stop(int tunnelId) => Future<void>.value();

  @override
  Future<void> delete(int tunnelId) => Future<void>.value();
}
