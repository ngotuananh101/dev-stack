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
import 'package:dev_stack/features/tunnels/domain/tunnel_session.dart';
import 'package:dev_stack/features/tunnels/presentation/widgets/tunnel_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // A table is only as wide as the rows it holds, so an empty table proves
  // nothing. These rows carry the long names and many actions that make a
  // real table wider than an empty one.
  final app = AppModel(
    appId: 'php',
    name: 'PHP 8.3 with a very long application name',
    description: 'PHP interpreter',
    categories: const ['webserver'],
    versions: const ['8.3.0'],
    isInstalled: true,
  );
  final site = SiteModel(
    id: 1,
    domain: 'a-very-long-site-domain-name.test',
    rootDir: '/projects/a-very-long-project-directory-name',
    siteType: 'cli',
    command: 'npm run dev',
    port: 3000,
  );
  final tunnel = TunnelModel(
    id: 1,
    name: 'A tunnel with a long name',
    provider: 'cloudflare',
    targetType: 'site',
    targetSiteDomain: 'a-very-long-site-domain-name.test',
  );
  final program = SupervisorProgram(
    id: 1,
    name: 'A supervisor program with a long name',
    command: 'npm run watch',
    workingDir: '/projects/a-very-long-project-directory-name',
  );
  final job = CronJob(
    id: 1,
    name: 'A cron job with a long name',
    schedule: '*/5 * * * *',
    command: 'php artisan schedule:run',
    workingDir: '/projects/a-very-long-project-directory-name',
  );
  final database = DatabaseRecord()
    ..id = 1
    ..name = 'a_database_with_a_very_long_name'
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
      sessions: {
        1: const TunnelSession(
          tunnelId: 1,
          status: TunnelStatus.running,
          publicUrl:
              'https://a-very-long-subdomain-name-here.trycloudflare.com',
        ),
      },
      onStart: (_) {},
      onStop: (_) {},
      onCancel: (_) {},
      onEdit: (_) {},
      onDelete: (_) {},
      onViewLogs: (_) {},
      onOpenUrl: (_) {},
      onCopyUrl: (_) {},
      onOpenQr: (_, url) {},
    ),
    'supervisor': () => SupervisorTable(
      programs: [program],
      statuses: const {},
      pids: const {},
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

  for (final entry in tables.entries) {
    testWidgets('the ${entry.key} table fits every window width', (
      tester,
    ) async {
      final failures = <String>[];
      for (var width = 720; width <= 1600; width += 20) {
        await tester.binding.setSurfaceSize(Size(width.toDouble(), 700));
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(24),
                  child: entry.value(),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        final error = tester.takeException();
        if (error != null) {
          failures.add('$width px: $error');
        }
      }
      addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

      expect(
        failures,
        isEmpty,
        reason: 'the ${entry.key} table must fit every window width',
      );
    });
  }
}
