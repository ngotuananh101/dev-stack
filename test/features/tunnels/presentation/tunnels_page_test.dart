import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dev_stack/features/tunnels/presentation/tunnels_page.dart';
import 'package:dev_stack/features/tunnels/data/tunnels_provider.dart';
import 'package:dev_stack/features/tunnels/domain/tunnel_model.dart';
import 'package:dev_stack/features/tunnels/domain/tunnel_session.dart';
import 'package:dio/dio.dart';
import 'package:flutter/src/material/material_localizations.dart'
    as flutter_material_localizations;
import 'package:toastification/toastification.dart';
import 'package:dev_stack/features/tunnels/data/tunnel_downloader_service.dart';
import 'package:dev_stack/shared/widgets/app_button.dart';

void main() {
  testWidgets('TunnelsPage renders header and empty state', (tester) async {
    // The header now holds three buttons; at the default 800px surface
    // the title column is squeezed to ~95px and its description wraps to
    // several lines, which grows the row and moves the buttons down. The
    // app opens at 1024px, so the same-row assertion is checked at a
    // realistic desktop width instead.
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tunnelsStreamProvider.overrideWith((ref) => Stream.value([])),
          tunnelSessionsProvider.overrideWith(
            () => TunnelSessionsNotifierMock({}),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: TunnelsPage())),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Tunnels'), findsOneWidget);
    expect(find.text('New Tunnel'), findsOneWidget);
    expect(find.text('No tunnels configured yet'), findsOneWidget);

    // New Tunnel button is placed on the right side on the same row with the title
    final tunnelsPos = tester.getTopLeft(find.text('Tunnels'));
    final newTunnelPos = tester.getTopLeft(
      find.widgetWithText(AppButton, 'New Tunnel'),
    );
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
          tunnelsStreamProvider.overrideWith(
            (ref) => Stream.value([mockTunnel]),
          ),
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
        child: const MaterialApp(home: Scaffold(body: TunnelsPage())),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Shopify Webhook'), findsOneWidget);
    expect(find.text('https://myshop.trycloudflare.com'), findsOneWidget);
  });

  testWidgets('Update cloudflared button downloads the latest binary', (
    tester,
  ) async {
    final downloader = FakeTunnelDownloader();
    await pumpTunnelsPage(tester, downloader: downloader);

    // Both Update buttons sit in the header, left of New Tunnel.
    final cloudflaredPos = tester.getTopLeft(
      find.widgetWithText(AppButton, 'Update cloudflared'),
    );
    final ngrokPos = tester.getTopLeft(
      find.widgetWithText(AppButton, 'Update ngrok'),
    );
    final newTunnelPos = tester.getTopLeft(
      find.widgetWithText(AppButton, 'New Tunnel'),
    );
    expect(cloudflaredPos.dx, lessThan(ngrokPos.dx));
    expect(ngrokPos.dx, lessThan(newTunnelPos.dx));

    await tester.tap(
      find.widgetWithText(AppButton, 'Update cloudflared'),
    );
    await settleToast(tester);

    expect(downloader.downloadedProviders, ['cloudflare']);
    expect(
      find.text('cloudflared updated to the latest version'),
      findsOneWidget,
    );

    await drainToastTimers(tester);
  });

  testWidgets('Update does not download while a Cloudflare tunnel is running', (
    tester,
  ) async {
    final downloader = FakeTunnelDownloader();
    final tunnel = TunnelModel(
      id: 10,
      name: 'Shop',
      provider: 'cloudflare',
      targetPort: 80,
    );
    await pumpTunnelsPage(
      tester,
      tunnels: [tunnel],
      sessions: {
        10: const TunnelSession(
          tunnelId: 10,
          status: TunnelStatus.running,
        ),
      },
      downloader: downloader,
    );

    await tester.tap(
      find.widgetWithText(AppButton, 'Update cloudflared'),
    );
    await settleToast(tester);

    expect(downloader.downloadedProviders, isEmpty);
    expect(
      find.text('Stop the running Cloudflare tunnel first, then update.'),
      findsOneWidget,
    );

    await drainToastTimers(tester);
  });

  testWidgets(
    'Update does not download while a Cloudflare tunnel is downloading its binary',
    (tester) async {
      final downloader = FakeTunnelDownloader();
      final tunnel = TunnelModel(
        id: 10,
        name: 'Shop',
        provider: 'cloudflare',
        targetPort: 80,
      );
      await pumpTunnelsPage(
        tester,
        tunnels: [tunnel],
        sessions: {
          10: const TunnelSession(
            tunnelId: 10,
            status: TunnelStatus.downloadingBinary,
          ),
        },
        downloader: downloader,
      );

      await tester.tap(
        find.widgetWithText(AppButton, 'Update cloudflared'),
      );
      await settleToast(tester);

      expect(downloader.downloadedProviders, isEmpty);
      expect(
        find.text('Stop the running Cloudflare tunnel first, then update.'),
        findsOneWidget,
      );

      await drainToastTimers(tester);
    },
  );

  testWidgets('Update shows an error dialog when the download fails', (
    tester,
  ) async {
    final downloader = FakeTunnelDownloader(shouldThrow: true);
    await pumpTunnelsPage(tester, downloader: downloader);

    await tester.tap(
      find.widgetWithText(AppButton, 'Update cloudflared'),
    );
    await settleDialog(tester);

    expect(find.text('Could not update cloudflared'), findsOneWidget);
    expect(find.textContaining('network down'), findsOneWidget);
    expect(find.text('CLOSE'), findsOneWidget);
    // The button stops spinning only after the dialog is dismissed:
    // the handler awaits showErrorFrom, so the finally that clears
    // _updating runs after the pop.
    await tester.tap(find.text('CLOSE'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(
      find.widgetWithText(AppButton, 'Update cloudflared'),
      findsOneWidget,
    );
  });

  testWidgets('Update works while the tunnel list is still loading', (
    tester,
  ) async {
    final downloader = FakeTunnelDownloader();
    final neverStream = StreamController<List<TunnelModel>>().stream;
    await pumpTunnelsPage(
      tester,
      tunnelsStream: neverStream,
      downloader: downloader,
      settle: false,
    );

    expect(
      find.widgetWithText(AppButton, 'Update cloudflared'),
      findsOneWidget,
    );

    await tester.tap(
      find.widgetWithText(AppButton, 'Update cloudflared'),
    );
    await settleToast(tester);

    expect(downloader.downloadedProviders, ['cloudflare']);
    expect(
      find.text('cloudflared updated to the latest version'),
      findsOneWidget,
    );

    await drainToastTimers(tester);
  });

  testWidgets('Update ngrok button downloads the latest binary', (
    tester,
  ) async {
    final downloader = FakeTunnelDownloader();
    await pumpTunnelsPage(tester, downloader: downloader);

    await tester.tap(find.widgetWithText(AppButton, 'Update ngrok'));
    await settleToast(tester);

    expect(downloader.downloadedProviders, ['ngrok']);
    expect(
      find.text('ngrok updated to the latest version'),
      findsOneWidget,
    );

    await drainToastTimers(tester);
  });

  testWidgets('Update ngrok does not download while an ngrok tunnel is running', (
    tester,
  ) async {
    final downloader = FakeTunnelDownloader();
    final tunnel = TunnelModel(
      id: 11,
      name: 'API',
      provider: 'ngrok',
      targetPort: 3000,
    );
    await pumpTunnelsPage(
      tester,
      tunnels: [tunnel],
      sessions: {
        11: const TunnelSession(
          tunnelId: 11,
          status: TunnelStatus.running,
        ),
      },
      downloader: downloader,
    );

    await tester.tap(find.widgetWithText(AppButton, 'Update ngrok'));
    await settleToast(tester);

    expect(downloader.downloadedProviders, isEmpty);
    expect(
      find.text('Stop the running ngrok tunnel first, then update.'),
      findsOneWidget,
    );

    await drainToastTimers(tester);

    // A running ngrok tunnel does not block the cloudflared update.
    await tester.tap(
      find.widgetWithText(AppButton, 'Update cloudflared'),
    );
    await settleToast(tester);

    expect(downloader.downloadedProviders, ['cloudflare']);
    expect(
      find.text('cloudflared updated to the latest version'),
      findsOneWidget,
    );

    await drainToastTimers(tester);
  });

  testWidgets('Update ngrok shows an error dialog when the download fails', (
    tester,
  ) async {
    final downloader = FakeTunnelDownloader(shouldThrow: true);
    await pumpTunnelsPage(tester, downloader: downloader);

    await tester.tap(find.widgetWithText(AppButton, 'Update ngrok'));
    await settleDialog(tester);

    expect(find.text('Could not update ngrok'), findsOneWidget);
    expect(find.textContaining('network down'), findsOneWidget);
    expect(find.text('CLOSE'), findsOneWidget);
    await tester.tap(find.text('CLOSE'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.widgetWithText(AppButton, 'Update ngrok'), findsOneWidget);
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

/// Records `downloadBinary` calls and either completes or throws, so the
/// Update-button tests never touch the network.
class FakeTunnelDownloader extends TunnelDownloaderService {
  FakeTunnelDownloader({this.shouldThrow = false});

  final bool shouldThrow;
  final List<String> downloadedProviders = [];

  @override
  Future<void> downloadBinary(
    String provider, {
    void Function(double progress)? onProgress,
    Dio? dio,
    CancelToken? cancelToken,
  }) async {
    downloadedProviders.add(provider);
    if (shouldThrow) throw Exception('network down');
  }
}

/// Pumps [TunnelsPage] wrapped the way the real app wraps it: toasts need
/// the [ToastificationWrapper], and QuickAlert's error dialog needs
/// Flutter's MaterialLocalizations (mirrors main.dart).
Future<void> pumpTunnelsPage(
  WidgetTester tester, {
  List<TunnelModel> tunnels = const [],
  Map<int, TunnelSession> sessions = const {},
  TunnelDownloaderService? downloader,
  Stream<List<TunnelModel>>? tunnelsStream,
  bool settle = true,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tunnelsStreamProvider.overrideWith(
          (ref) => tunnelsStream ?? Stream.value(tunnels),
        ),
        tunnelSessionsProvider.overrideWith(
          () => TunnelSessionsNotifierMock(sessions),
        ),
        if (downloader != null)
          tunnelDownloaderServiceProvider.overrideWithValue(downloader),
      ],
      child: ToastificationWrapper(
        child: MaterialApp(
          localizationsDelegates: const [
            flutter_material_localizations
                .DefaultMaterialLocalizations
                .delegate,
          ],
          home: const Scaffold(body: TunnelsPage()),
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    // No settle: the loading spinner animates forever, so pumpAndSettle
    // would time out. One frame is enough for the header to render.
    await tester.pump();
  }
}

/// Lets a toast's enqueue/entry animation finish after a tap.
///
/// The toast is inserted from a post-frame callback, so it needs a frame
/// after the tap before it exists, then a few hundred milliseconds for its
/// entry animation to reach full size.
Future<void> settleToast(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 700));
}

/// Lets a QuickAlert dialog finish its entry animation after a tap.
///
/// Do not use pumpAndSettle here: while the dialog is open the Update
/// button is still spinning (the handler awaits the dialog's dismissal),
/// and the spinner animates forever.
Future<void> settleDialog(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 700));
}

/// Runs past the toast's own auto-close timer so no pending timer outlives
/// the test.
Future<void> drainToastTimers(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 4));
  await tester.pump(const Duration(milliseconds: 700));
}

