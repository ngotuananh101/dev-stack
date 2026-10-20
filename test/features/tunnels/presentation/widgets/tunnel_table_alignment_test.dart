import 'package:dev_stack/features/tunnels/domain/tunnel_model.dart';
import 'package:dev_stack/features/tunnels/domain/tunnel_session.dart';
import 'package:dev_stack/features/tunnels/presentation/widgets/tunnel_table.dart';
import 'package:dev_stack/shared/widgets/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t1 = TunnelModel(
    id: 1,
    name: 'Shopify Webhook',
    provider: 'cloudflare',
    targetType: 'site',
    targetSiteDomain: 'myshop.test',
    targetPort: 80,
  );
  final t2 = TunnelModel(
    id: 2,
    name: 'API Port Tunnel',
    provider: 'ngrok',
    targetType: 'port',
    targetPort: 3000,
  );

  Widget host(List<TunnelModel> tunnels,
      {Map<int, TunnelSession> sessions = const {}}) {
    return MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            Expanded(
              child: TunnelTable(
                tunnels: tunnels,
                sessions: sessions,
                onStart: (_) {},
                onStop: (_) {},
                onCancel: (_) {},
                onEdit: (_) {},
                onDelete: (_) {},
                onViewLogs: (_) {},
                onOpenUrl: (_) {},
                onCopyUrl: (_) {},
                onOpenQr: (_, __) {},
              ),
            ),
          ]),
        ),
      ),
    );
  }

  testWidgets('header and rows line up on the same columns at a wide window',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1163, 720));
    addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

    await tester.pumpWidget(host([t1, t2], sessions: {
      1: const TunnelSession(tunnelId: 1, status: TunnelStatus.running),
      2: const TunnelSession(
        tunnelId: 2,
        status: TunnelStatus.running,
        publicUrl: 'https://abc.ngrok.io',
      ),
    }));
    await tester.pumpAndSettle();

    final statusHeaderX = tester.getTopLeft(find.text('STATUS')).dx;
    final statusChipX = tester.getTopLeft(find.byType(StatusChip).first).dx;
    expect(statusChipX, closeTo(statusHeaderX, 1),
        reason: 'status chips start where the STATUS header starts');
  });

  testWidgets('survives a ~412px row without overflow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(700, 720));
    addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

    await tester.pumpWidget(host([
      t1,
      t2
    ], sessions: {
      2: const TunnelSession(
        tunnelId: 2,
        status: TunnelStatus.running,
        publicUrl: 'https://abc.ngrok.io',
      ),
    }));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
