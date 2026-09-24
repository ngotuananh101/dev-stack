import 'package:dev_stack/features/tunnels/domain/tunnel_model.dart';
import 'package:dev_stack/features/tunnels/domain/tunnel_session.dart';
import 'package:dev_stack/features/tunnels/presentation/widgets/tunnel_table.dart';
import 'package:dev_stack/shared/widgets/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  final testTunnel1 = TunnelModel(
    id: 1,
    name: 'Shopify Webhook',
    provider: 'cloudflare',
    targetType: 'site',
    targetSiteDomain: 'myshop.test',
    targetPort: 80,
  );

  final testTunnel2 = TunnelModel(
    id: 2,
    name: 'API Port Tunnel',
    provider: 'ngrok',
    targetType: 'port',
    targetPort: 3000,
  );

  testWidgets('TunnelTable renders header columns and empty state', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 720));
    addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TunnelTable(
            tunnels: const [],
            sessions: const {},
            onStart: (_) {},
            onStop: (_) {},
            onEdit: (_) {},
            onDelete: (_) {},
            onViewLogs: (_) {},
            onOpenUrl: (_) {},
            onCopyUrl: (_) {},
            onOpenQr: (t, u) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('TUNNEL NAME'), findsOneWidget);
    expect(find.text('PROVIDER'), findsOneWidget);
    expect(find.text('TARGET'), findsOneWidget);
    expect(find.text('STATUS'), findsOneWidget);
    expect(find.text('PUBLIC URL'), findsOneWidget);
    expect(find.text('OPERATE'), findsOneWidget);
    expect(find.text('No tunnels configured yet'), findsOneWidget);
  });

  testWidgets('TunnelTable renders rows with running, stopped and connecting states', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 720));
    addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

    final sessions = {
      1: const TunnelSession(
        tunnelId: 1,
        status: TunnelStatus.running,
        publicUrl: 'https://myshop.trycloudflare.com',
      ),
      2: const TunnelSession(
        tunnelId: 2,
        status: TunnelStatus.stopped,
      ),
    };

    TunnelModel? startedTunnel;
    int? stoppedTunnelId;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TunnelTable(
            tunnels: [testTunnel1, testTunnel2],
            sessions: sessions,
            onStart: (t) => startedTunnel = t,
            onStop: (id) => stoppedTunnelId = id,
            onEdit: (_) {},
            onDelete: (_) {},
            onViewLogs: (_) {},
            onOpenUrl: (_) {},
            onCopyUrl: (_) {},
            onOpenQr: (t, u) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Headers
    expect(find.text('TUNNEL NAME'), findsOneWidget);

    // Row 1: Shopify Webhook
    expect(find.text('Shopify Webhook'), findsOneWidget);
    expect(find.text('Cloudflare'), findsOneWidget);
    expect(find.text('myshop.test'), findsOneWidget);
    expect(find.text('https://myshop.trycloudflare.com'), findsOneWidget);
    expect(find.text('RUNNING'), findsOneWidget);

    // Row 2: API Port Tunnel
    expect(find.text('API Port Tunnel'), findsOneWidget);
    expect(find.text('Ngrok'), findsOneWidget);
    expect(find.text('Port 3000'), findsOneWidget);
    expect(find.text('Not running'), findsOneWidget);
    expect(find.text('STOPPED'), findsOneWidget);

    // Stop button on running tunnel
    expect(find.widgetWithText(StatusChip, 'RUNNING'), findsOneWidget);
    final stopButton = find.text('Stop');
    expect(stopButton, findsOneWidget);
    await tester.tap(stopButton);
    expect(stoppedTunnelId, 1);

    // Start button on stopped tunnel
    final startButton = find.text('Start');
    expect(startButton, findsOneWidget);
    await tester.tap(startButton);
    expect(startedTunnel?.id, 2);
  });
}
