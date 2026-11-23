import 'dart:async';

import 'package:dev_stack/features/sites/data/cli_process_manager.dart';
import 'package:dev_stack/features/sites/domain/site_model.dart';
import 'package:dev_stack/features/sites/presentation/widgets/site_logs_modal.dart';
import 'package:dev_stack/shared/widgets/terminal_log_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

class _FakeCliProcessManager extends CliProcessManager {
  _FakeCliProcessManager({
    List<String>? initialBuffer,
    StreamController<String>? controller,
  }) : initialBuffer = initialBuffer ?? const [],
       controller = controller ?? StreamController<String>.broadcast();

  final List<String> initialBuffer;
  final StreamController<String> controller;
  int? clearedSiteId;

  @override
  List<String> getLogBuffer(int siteId) => List<String>.from(initialBuffer);

  @override
  Stream<String> getLogStream(int siteId) => controller.stream;

  @override
  void clearLogs(int siteId) {
    clearedSiteId = siteId;
  }
}

SiteModel _buildSite() => SiteModel(
  id: 1,
  domain: 'my-cli-app.test',
  rootDir: '/test',
  siteType: 'cli',
  command: 'npm run dev',
  port: 3000,
);

Widget _buildApp(_FakeCliProcessManager manager, SiteModel site) {
  return ProviderScope(
    overrides: [cliProcessManagerProvider.overrideWithValue(manager)],
    child: MaterialApp(
      home: Scaffold(body: SiteLogsModal(site: site)),
    ),
  );
}

void main() {
  testWidgets('SiteLogsModal displays site domain and action buttons', (
    tester,
  ) async {
    final manager = _FakeCliProcessManager();
    final site = _buildSite();

    await tester.pumpWidget(_buildApp(manager, site));

    expect(find.text('Logs: my-cli-app.test'), findsOneWidget);
    expect(find.byIcon(Icons.clear_all), findsOneWidget);
    expect(find.byIcon(Icons.copy), findsOneWidget);

    await manager.controller.close();
  });

  testWidgets('SiteLogsModal keeps a bounded tail of latest 1000 lines on burst', (
    tester,
  ) async {
    final controller = StreamController<String>.broadcast(sync: true);
    final manager = _FakeCliProcessManager(controller: controller);
    final site = _buildSite();

    await tester.pumpWidget(_buildApp(manager, site));

    for (var i = 0; i < 1200; i++) {
      controller.add('line $i');
    }
    await tester.pump();

    final terminal = tester.widget<TerminalLogView>(
      find.byType(TerminalLogView),
    );
    expect(terminal.lines.length, 1000);
    expect(terminal.lines.first, 'line 200');
    expect(terminal.lines.last, 'line 1199');
    expect(find.text('line 1199'), findsOneWidget);

    await controller.close();
  });

  testWidgets('SiteLogsModal caps initial buffer to latest 1000 lines', (
    tester,
  ) async {
    final initial = List<String>.generate(1200, (i) => 'init $i');
    final manager = _FakeCliProcessManager(initialBuffer: initial);
    final site = _buildSite();

    await tester.pumpWidget(_buildApp(manager, site));

    final terminal = tester.widget<TerminalLogView>(
      find.byType(TerminalLogView),
    );
    expect(terminal.lines.length, 1000);
    expect(terminal.lines.first, 'init 200');
    expect(terminal.lines.last, 'init 1199');

    await manager.controller.close();
  });

  testWidgets('SiteLogsModal clears logs and manager buffer', (tester) async {
    final manager = _FakeCliProcessManager(initialBuffer: ['a', 'b', 'c']);
    final site = _buildSite();

    await tester.pumpWidget(_buildApp(manager, site));

    expect(
      tester.widget<TerminalLogView>(find.byType(TerminalLogView)).lines,
      isNotEmpty,
    );

    await tester.tap(find.byIcon(Icons.clear_all));
    await tester.pump();

    expect(manager.clearedSiteId, 1);
    expect(
      tester.widget<TerminalLogView>(find.byType(TerminalLogView)).lines,
      isEmpty,
    );
    expect(find.text('No logs available yet.'), findsOneWidget);

    await manager.controller.close();
  });
}
