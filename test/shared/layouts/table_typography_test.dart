import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:dev_stack/features/apps/presentation/widgets/compact_apps_table.dart';
import 'package:dev_stack/features/cron/domain/cron_job.dart';
import 'package:dev_stack/features/cron/presentation/widgets/cron_table.dart';
import 'package:dev_stack/features/databases/domain/database_record.dart';
import 'package:dev_stack/features/databases/presentation/widgets/database_table.dart';
import 'package:dev_stack/features/sites/domain/site_model.dart';
import 'package:dev_stack/features/sites/presentation/widgets/site_table.dart';
import 'package:dev_stack/features/supervisor/domain/supervisor_program.dart';
import 'package:dev_stack/features/supervisor/presentation/widgets/supervisor_table.dart';
import 'package:dev_stack/features/tunnels/domain/tunnel_model.dart';
import 'package:dev_stack/features/tunnels/presentation/widgets/tunnel_table.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A table reads on a documented size palette: headers 10, row cells 10,
/// name columns 12, status chips 8 and the version tag 8. The header is told
/// apart by weight and its smaller size; colour is the same white for both. These tests read the real
/// rendered styles, so a call site that reaches for another token fails here
/// rather than on screen.
void main() {
  Color? colorOf(Text text) => text.style?.color;
  FontWeight? weightOf(Text text) => text.style?.fontWeight;

  double? sizeOf(Text text) => text.style?.fontSize;

  /// Every distinct size the table renders, header included.
  Set<double?> renderedSizes(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map(sizeOf)
      .whereType<double>()
      .toSet();

  Widget host(Widget table) => ProviderScope(
    child: MaterialApp(
      home: Scaffold(
        body: Padding(padding: const EdgeInsets.all(24), child: table),
      ),
    ),
  );

  final app = AppModel(
    appId: 'php',
    name: 'PHP 8.3',
    description: 'PHP interpreter',
    categories: const ['runtime'],
    versions: const ['8.3.0'],
    isInstalled: true,
    installedVersion: '8.3.0',
  );
  final site = SiteModel(
    id: 1,
    domain: 'demo.test',
    rootDir: '/projects/demo',
    siteType: 'cli',
    command: 'npm run dev',
    port: 3000,
  );
  final tunnel = TunnelModel(
    id: 1,
    name: 'Demo tunnel',
    provider: 'cloudflare',
    targetType: 'site',
    targetSiteDomain: 'demo.test',
  );
  final program = SupervisorProgram(
    id: 1,
    name: 'Queue Worker',
    command: 'php artisan queue:work',
    workingDir: '/srv/app',
  );
  final job = CronJob(
    id: 1,
    name: 'Nightly job',
    schedule: '*/5 * * * *',
    command: 'php artisan schedule:run',
    workingDir: '/srv/app',
  );
  final database = DatabaseRecord()
    ..id = 1
    ..name = 'demo'
    ..username = 'root'
    ..password = ''
    ..engineAppId = 'mysql'
    ..createdAt = DateTime(2026);

  final tables = <String, Widget Function()>{
    'apps': () => CompactAppsTable(
      apps: [app],
      onToggleInstall: (_) async {},
      onTogglePath: (_) async {},
      onStartService: (_) async {},
      onStopService: (_) async {},
      onRestartService: (_) async {},
      onChangeDefault: (_) async {},
      onOpen: (_) async {},
      onCancelInstall: (_) {},
    ),
    'sites': () => SiteTable(
      sites: [site],
      selectedIds: const {},
      onEdit: (_) {},
      onToggleSelection: (_) {},
      onToggleAll: (_) {},
    ),
    'tunnels': () => TunnelTable(
      tunnels: [tunnel],
      sessions: const {},
      onStart: (_) {},
      onStop: (_) {},
      onCancel: (_) {},
      onEdit: (_) {},
      onDelete: (_) {},
      onViewLogs: (_) {},
      onOpenUrl: (_) {},
      onCopyUrl: (_) {},
      onOpenQr: (_, _) {},
    ),
    'supervisor': () => SupervisorTable(
      programs: [program],
      statuses: const {},
      pids: const {1: 4242},
      onStart: (_) {},
      onStop: (_) {},
      onRestart: (_) {},
      onViewLogs: (_) {},
      onEdit: (_) {},
      onDelete: (_) {},
    ),
    'cron': () => CronTable(
      jobs: [job],
      runningIds: const {},
      onRunNow: (_) {},
      onToggleEnabled: (_) {},
      onViewHistory: (_) {},
      onEdit: (_) {},
      onDelete: (_) {},
    ),
    'databases': () => DatabaseTable(
      databases: [database],
      engineId: 'mysql',
      onDelete: (_) {},
      onEdit: (_) {},
    ),
  };

  // The documented size palette per table: headers 10, row cells 10, name
  // columns 12, status chips 8, version tag 8.
  final expectedSizes = <String, Set<double>>{
    'apps': {10.0, 12.0, 8.0},
    'sites': {10.0, 12.0},
    'tunnels': {10.0, 12.0, 8.0},
    'supervisor': {10.0, 12.0, 8.0},
    'cron': {10.0, 12.0, 8.0},
    'databases': {10.0, 12.0},
  };

  for (final entry in tables.entries) {
    testWidgets(
      'the ${entry.key} table renders at the documented sizes',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 720));
        addTearDown(
          () => tester.binding.setSurfaceSize(const Size(800, 600)),
        );

        await tester.pumpWidget(host(entry.value()));
        await tester.pumpAndSettle();

        expect(
          renderedSizes(tester),
          expectedSizes[entry.key],
          reason: 'headers 10, cells 10, names 12, chips and tag 8',
        );
      },
    );
  }

  testWidgets(
    'a table header is smaller than its cells, and distinguished by weight',
    (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

    await tester.pumpWidget(
      host(
        SupervisorTable(
          programs: [program],
          statuses: const {},
          pids: const {1: 4242},
          onStart: (_) {},
          onStop: (_) {},
          onRestart: (_) {},
          onViewLogs: (_) {},
          onEdit: (_) {},
          onDelete: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final header = tester.widget<Text>(find.text('PROGRAM'));
    final cell = tester.widget<Text>(find.text('Queue Worker'));

    expect(sizeOf(header), 10.0, reason: 'header sits one step below the body');
    expect(sizeOf(cell), 12.0, reason: 'the name column reads at the body size');
    expect(weightOf(header), FontWeight.w600);
    expect(
      colorOf(header),
      colorOf(cell),
      reason: 'one flat text colour: the reset made every text token white',
    );
  });

  final expectedEmptySizes = <String, Set<double>>{
    'apps': {10.0},
    'sites': {10.0},
    'tunnels': {10.0, 12.0},
    'supervisor': {10.0, 12.0},
    'cron': {10.0, 12.0},
    'databases': {10.0, 12.0},
  };

  for (final entry in tables.entries) {
    testWidgets(
      'the ${entry.key} table empty state sits on the documented sizes',
      (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 720));
      addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

      final empty = switch (entry.key) {
        'apps' => CompactAppsTable(
          apps: const [],
          onToggleInstall: (_) async {},
          onTogglePath: (_) async {},
          onStartService: (_) async {},
          onStopService: (_) async {},
          onRestartService: (_) async {},
          onChangeDefault: (_) async {},
          onOpen: (_) async {},
          onCancelInstall: (_) {},
        ),
        'sites' => SiteTable(
          sites: const [],
          selectedIds: const {},
          onEdit: (_) {},
          onToggleSelection: (_) {},
          onToggleAll: (_) {},
        ),
        'tunnels' => TunnelTable(
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
          onOpenQr: (_, _) {},
        ),
        'supervisor' => SupervisorTable(
          programs: const [],
          statuses: const {},
          pids: const {},
          onStart: (_) {},
          onStop: (_) {},
          onRestart: (_) {},
          onViewLogs: (_) {},
          onEdit: (_) {},
          onDelete: (_) {},
        ),
        'cron' => CronTable(
          jobs: const [],
          runningIds: const {},
          onRunNow: (_) {},
          onToggleEnabled: (_) {},
          onViewHistory: (_) {},
          onEdit: (_) {},
          onDelete: (_) {},
        ),
        _ => DatabaseTable(
          databases: const [],
          engineId: 'mysql',
          onDelete: (_) {},
          onEdit: (_) {},
        ),
      };

      await tester.pumpWidget(host(empty));
      await tester.pumpAndSettle();

      // `FilledButton`/`TextButton` inside tables bring the theme's own label
      // size, which is pinned by the theme test; here only the table's own text
      // matters, so chips and buttons are read too and must not drift either.
      expect(renderedSizes(tester), expectedEmptySizes[entry.key]);
    });
  }
}
