import 'dart:async';
import 'package:dev_stack/features/sites/data/cli_process_manager.dart';
import 'package:dev_stack/features/sites/domain/site_model.dart';
import 'package:dev_stack/features/sites/presentation/widgets/site_logs_modal.dart';
import 'package:dev_stack/features/sites/presentation/widgets/site_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class FakeCliProcessManager extends CliProcessManager {
  final StreamController<int> _controller = StreamController<int>.broadcast();
  final Set<int> _runningSites = {};
  int startCalls = 0;
  int stopCalls = 0;
  int restartCalls = 0;

  @override
  Stream<int> get statusStream => _controller.stream;

  @override
  bool isSiteRunning(int siteId) => _runningSites.contains(siteId);

  void setRunning(int siteId, bool running) {
    if (running) {
      _runningSites.add(siteId);
    } else {
      _runningSites.remove(siteId);
    }
    _controller.add(siteId);
  }

  @override
  Future<bool> startSite(SiteModel site) async {
    startCalls++;
    setRunning(site.id, true);
    return true;
  }

  @override
  Future<bool> stopSite(int siteId) async {
    stopCalls++;
    setRunning(siteId, false);
    return true;
  }

  @override
  Future<bool> restartSite(SiteModel site) async {
    restartCalls++;
    return true;
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }
}

void main() {
  testWidgets('SiteTable renders CLI badge, tooltip, and action buttons', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final site = SiteModel(
      id: 12,
      domain: 'myapp.test',
      rootDir: '/my/project',
      siteType: 'cli',
      command: 'npm run dev',
      port: 3000,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SiteTable(
              sites: [site],
              selectedIds: const {},
              onEdit: (_) {},
              onToggleSelection: (_) {},
              onToggleAll: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify TYPE column CLI badge
    expect(find.text('CLI :3000'), findsOneWidget);

    // Verify action buttons
    expect(find.byIcon(LucideIcons.play), findsOneWidget);
    expect(find.byIcon(LucideIcons.rotateCw), findsOneWidget);
    expect(find.byIcon(LucideIcons.scrollText), findsOneWidget);

    // Verify rootDir is rendered with command tooltip
    expect(find.text('/my/project'), findsOneWidget);
    final tooltip = tester.widget<Tooltip>(
      find.byWidgetPredicate(
        (w) => w is Tooltip && w.message == 'Command: npm run dev',
      ),
    );
    expect(tooltip.message, 'Command: npm run dev');
  });

  testWidgets('SiteTable opens SiteLogsModal when clicking logs button', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final site = SiteModel(
      id: 12,
      domain: 'myapp.test',
      rootDir: '/my/project',
      siteType: 'cli',
      command: 'npm run dev',
      port: 3000,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SiteTable(
              sites: [site],
              selectedIds: const {},
              onEdit: (_) {},
              onToggleSelection: (_) {},
              onToggleAll: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap logs button
    await tester.tap(find.byIcon(LucideIcons.scrollText));
    await tester.pumpAndSettle();

    // SiteLogsModal should be displayed
    expect(find.byType(SiteLogsModal), findsOneWidget);
    expect(find.text('Logs: myapp.test'), findsOneWidget);
  });

  testWidgets('SiteTable controls start, stop, and restart CLI site', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final fakeManager = FakeCliProcessManager();
    final site = SiteModel(
      id: 15,
      domain: 'cli-test.local',
      rootDir: '/path/to/app',
      siteType: 'cli',
      command: 'bun dev',
      port: 5000,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cliProcessManagerProvider.overrideWithValue(fakeManager),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SiteTable(
              sites: [site],
              selectedIds: const {},
              onEdit: (_) {},
              onToggleSelection: (_) {},
              onToggleAll: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Initially stopped -> Play button present, Square button absent
    expect(find.byIcon(LucideIcons.play), findsOneWidget);
    expect(find.byIcon(LucideIcons.square), findsNothing);

    // Tap Play button -> starts site
    await tester.tap(find.byIcon(LucideIcons.play));
    await tester.pumpAndSettle();

    expect(fakeManager.startCalls, 1);
    expect(find.byIcon(LucideIcons.square), findsOneWidget);
    expect(find.byIcon(LucideIcons.play), findsNothing);

    // Tap Restart button while running -> calls restartSite
    await tester.tap(find.byIcon(LucideIcons.rotateCw));
    await tester.pumpAndSettle();
    expect(fakeManager.restartCalls, 1);

    // Tap Stop button (square) -> stops site
    await tester.tap(find.byIcon(LucideIcons.square));
    await tester.pumpAndSettle();

    expect(fakeManager.stopCalls, 1);
    expect(find.byIcon(LucideIcons.play), findsOneWidget);
    expect(find.byIcon(LucideIcons.square), findsNothing);
  });
}
