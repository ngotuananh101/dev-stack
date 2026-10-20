import 'package:dev_stack/features/tunnels/domain/tunnel_model.dart';
import 'package:dev_stack/features/tunnels/domain/tunnel_session.dart';
import 'package:dev_stack/features/tunnels/presentation/widgets/tunnel_table.dart';
import 'package:dev_stack/shared/widgets/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
            onCancel: (_) {},
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
            onCancel: (_) {},
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

  testWidgets('TunnelTable shows a Cancel button while a tunnel is starting', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 720));
    addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

    final sessions = {
      1: const TunnelSession(
        tunnelId: 1,
        status: TunnelStatus.downloadingBinary,
      ),
    };

    int? cancelledTunnelId;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TunnelTable(
            tunnels: [testTunnel1],
            sessions: sessions,
            onStart: (_) {},
            onStop: (_) {},
            onCancel: (id) => cancelledTunnelId = id,
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

    // While starting, the row offers Cancel instead of a spinner-only cell.
    final cancelButton = find.text('Cancel');
    expect(cancelButton, findsOneWidget);

    await tester.tap(cancelButton);
    expect(cancelledTunnelId, 1);
  });

  group('responsive actions', () {
    testWidgets('collapses every action into one menu at a ~412px row',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(700, 720));
      addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              Expanded(
                child: TunnelTable(
                  tunnels: [testTunnel1],
                  sessions: {
                    1: TunnelSession(
                      tunnelId: 1,
                      status: TunnelStatus.running,
                      publicUrl: 'https://slug.trycloudflare.com',
                    ),
                  },
                  onStart: (_) {},
                  onStop: (_) {},
                  onCancel: (_) {},
                  onViewLogs: (_) {},
                  onEdit: (_) {},
                  onDelete: (_) {},
                  onCopyUrl: (_) {},
                  onOpenUrl: (_) {},
                  onOpenQr: (_, _) {},
                ),
              ),
            ]),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // A RenderFlex overflow is a Flutter error, so the header and
      // every data row fitting the narrow window is proved by there
      // being no exception here.
      expect(tester.takeException(), isNull);

      // The URL is data and stays visible; the buttons around it move into the
      // row's menu so nothing is pushed out of reach.
      expect(find.text('https://slug.trycloudflare.com'), findsOneWidget);
      expect(find.text('Stop'), findsNothing);
      expect(find.byIcon(LucideIcons.copy), findsNothing);

      await tester.tap(find.byIcon(LucideIcons.moreHorizontal));
      await tester.pumpAndSettle();
      expect(find.text('Copy Link'), findsOneWidget);
      expect(find.text('Open in Browser'), findsOneWidget);
      expect(find.text('QR Code'), findsOneWidget);
      expect(find.text('View Logs'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Stop'), findsOneWidget);
    });

    testWidgets('shows every action inline at a wide row', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 720));
      addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              Expanded(
                child: TunnelTable(
                  tunnels: [testTunnel1],
                  sessions: {
                    1: TunnelSession(
                      tunnelId: 1,
                      status: TunnelStatus.running,
                      publicUrl: 'https://slug.trycloudflare.com',
                    ),
                  },
                  onStart: (_) {},
                  onStop: (_) {},
                  onCancel: (_) {},
                  onViewLogs: (_) {},
                  onEdit: (_) {},
                  onDelete: (_) {},
                  onCopyUrl: (_) {},
                  onOpenUrl: (_) {},
                  onOpenQr: (_, _) {},
                ),
              ),
            ]),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(LucideIcons.copy), findsOneWidget);
      expect(find.byIcon(LucideIcons.moreHorizontal), findsNothing);
    });
  });
}
