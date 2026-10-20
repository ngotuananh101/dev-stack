import 'package:dev_stack/features/apps/data/apps_provider.dart';
import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:dev_stack/features/apps/presentation/widgets/app_settings_modal.dart';
import 'package:dev_stack/features/apps/presentation/widgets/app_version_modal.dart';
import 'package:dev_stack/features/apps/presentation/widgets/pyenv_manage_modal.dart';
import 'package:dev_stack/features/apps/presentation/widgets/service_logs_modal.dart';
import 'package:dev_stack/features/cron/presentation/widgets/cron_form_modal.dart';
import 'package:dev_stack/features/databases/presentation/widgets/add_database_modal.dart';
import 'package:dev_stack/features/databases/presentation/widgets/add_redis_key_modal.dart';
import 'package:dev_stack/features/settings/presentation/widgets/system_info_modal.dart';
import 'package:dev_stack/features/sites/domain/batch_models.dart';
import 'package:dev_stack/features/sites/domain/site_model.dart';
import 'package:dev_stack/features/sites/presentation/widgets/add_site_modal.dart';
import 'package:dev_stack/features/sites/presentation/widgets/batch_progress_dialog.dart';
import 'package:dev_stack/features/sites/presentation/widgets/edit_site_modal.dart';
import 'package:dev_stack/features/sites/presentation/widgets/site_logs_modal.dart';
import 'package:dev_stack/features/sites/presentation/widgets/site_tunnel_dialog.dart';
import 'package:dev_stack/features/supervisor/presentation/widgets/program_form_modal.dart';
import 'package:dev_stack/features/tunnels/presentation/widgets/create_tunnel_modal.dart';
import 'package:dev_stack/features/tunnels/presentation/widgets/tunnel_qr_modal.dart';
import 'package:dev_stack/features/tunnels/presentation/widgets/tunnel_logs_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _StaticAppsNotifier extends Apps {
  @override
  Future<List<AppModel>> build() async => const [];
}

void main() {
  // The window a modal may be resized to. [MediaQuery] reads the size from the
  // view, so the test drives the view rather than the surface.
  void setWindow(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  final app = AppModel(
    appId: 'nginx',
    name: 'Nginx',
    categories: const ['webserver'],
  );
  final site = SiteModel(
    id: 1,
    domain: 'my-project.test',
    rootDir: '/projects/my-project',
    siteType: 'php',
    phpVersion: '8.2',
    useSsl: true,
  );
  final modals = <String, Widget Function()>{
    'app version': () => AppVersionModal(app: app, onInstall: () {}, onClose: () {}),
    'app settings': () => AppSettingsModal(app: app, onClose: () {}),
    'pyenv manage': () => PyenvManageModal(app: app, onClose: () {}),
    'service logs': () => ServiceLogsModal(app: app, onClose: () {}),
    'add site': () => const AddSiteModal(),
    'edit site': () => EditSiteModal(site: site, onClose: () {}),
    'site logs': () => SiteLogsModal(site: site),
    'site tunnel': () => SiteTunnelDialog(site: site),
    'batch progress': () => BatchProgressDialog(
      title: 'Creating sites',
      progress: ValueNotifier(
        const BatchProgress(
          current: 2,
          total: 5,
          currentLabel: 'site-2.test',
          phase: BatchPhase.processing,
        ),
      ),
      onCancel: () {},
    ),
    'add database': () => AddDatabaseModal(engine: app, onClose: () {}),
    'add redis key': () => AddRedisKeyModal(
      engine: app,
      dbIndex: 0,
      onClose: () {},
    ),
    'system info': () => const SystemInfoModal(),
    'cron form': () => const CronFormModal(),
    'program form': () => const ProgramFormModal(),
    'create tunnel': () => const CreateTunnelModal(),
    'tunnel qr': () => TunnelQrModal(
      tunnelName: 'My Tunnel',
      publicUrl: 'https://example.trycloudflare.com',
    ),
    'tunnel logs': () => TunnelLogsModal(tunnelName: 'My Tunnel', session: null),
  };

  for (final entry in modals.entries) {
    testWidgets('the ${entry.key} modal fits every window width', (
      tester,
    ) async {
      // The window can be resized to any width, so every width must work.
      final failures = <String>[];
      for (var width = 720; width <= 1600; width += 40) {
        setWindow(tester, Size(width.toDouble(), 800));
        await tester.pumpWidget(
          ProviderScope(
            overrides: [appsProvider.overrideWith(_StaticAppsNotifier.new)],
            child: MaterialApp(home: Scaffold(body: entry.value())),
          ),
        );
        // A fixed number of frames rather than pumpAndSettle: some modals run
        // a perpetual animation, which would never let the tree settle.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final error = tester.takeException();
        if (error != null) {
          failures.add('$width px: $error');
        }
      }

      expect(
        failures,
        isEmpty,
        reason: 'the ${entry.key} modal must fit every window width',
      );
    });
  }
}
