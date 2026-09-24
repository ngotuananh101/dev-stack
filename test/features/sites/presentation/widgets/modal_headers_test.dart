import 'package:dev_stack/features/apps/data/apps_provider.dart';
import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:dev_stack/features/apps/presentation/widgets/app_settings_modal.dart';
import 'package:dev_stack/features/apps/presentation/widgets/pyenv_manage_modal.dart';
import 'package:dev_stack/features/databases/presentation/widgets/add_database_modal.dart';
import 'package:dev_stack/features/databases/presentation/widgets/add_redis_key_modal.dart';
import 'package:dev_stack/features/sites/domain/batch_models.dart';
import 'package:dev_stack/features/sites/domain/site_model.dart';
import 'package:dev_stack/features/sites/presentation/widgets/add_site_modal.dart';
import 'package:dev_stack/features/sites/presentation/widgets/batch_progress_dialog.dart';
import 'package:dev_stack/features/sites/presentation/widgets/edit_site_modal.dart';
import 'package:dev_stack/features/sites/presentation/widgets/site_tunnel_dialog.dart';
import 'package:dev_stack/features/tunnels/presentation/widgets/create_tunnel_modal.dart';
import 'package:dev_stack/features/tunnels/presentation/widgets/tunnel_qr_modal.dart';
import 'package:dev_stack/shared/widgets/app_modal_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class _StaticAppsNotifier extends Apps {
  final List<AppModel> _apps;
  _StaticAppsNotifier(this._apps);

  @override
  Future<List<AppModel>> build() => Future.value(_apps);
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('Modal Header Unification Across App', () {
    testWidgets('AddSiteModal has standard AppModalHeader', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1080, 720));
      addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appsProvider.overrideWith(() => _StaticAppsNotifier([])),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AddSiteModal(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppModalHeader), findsOneWidget);
      final header = tester.widget<AppModalHeader>(find.byType(AppModalHeader));
      expect(header.title, 'Add New Site');
      expect(header.subtitle, 'Configure a new virtual host for your project');
      expect(header.icon, LucideIcons.globe);
      expect(header.iconSize, 20.0);
    });

    testWidgets('EditSiteModal has standard AppModalHeader', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1080, 720));
      addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

      final site = SiteModel(
        id: 1,
        domain: 'mysite.test',
        rootDir: '/var/www',
        siteType: 'php',
        phpVersion: '8.2',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appsProvider.overrideWith(() => _StaticAppsNotifier([])),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: EditSiteModal(site: site, onClose: () {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppModalHeader), findsOneWidget);
      final header = tester.widget<AppModalHeader>(find.byType(AppModalHeader));
      expect(header.title, 'Site Settings: mysite.test');
      expect(header.icon, LucideIcons.globe);
      expect(header.iconSize, 20.0);
    });

    testWidgets('AppSettingsModal has standard AppModalHeader', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1080, 720));
      addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

      final app = AppModel(
        appId: 'nginx',
        name: 'Nginx',
        categories: ['webserver'],
        versions: ['1.24'],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appsProvider.overrideWith(() => _StaticAppsNotifier([])),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: AppSettingsModal(app: app, onClose: () {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppModalHeader), findsOneWidget);
      final header = tester.widget<AppModalHeader>(find.byType(AppModalHeader));
      expect(header.title, 'Nginx Settings');
      expect(header.subtitle, 'Manage configuration and extensions');
      expect(header.icon, LucideIcons.settings);
      expect(header.iconSize, 20.0);
    });

    testWidgets('PyenvManageModal has standard AppModalHeader', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1080, 720));
      addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

      final app = AppModel(
        appId: 'python',
        name: 'Python',
        categories: ['runtime'],
        versions: ['3.11'],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appsProvider.overrideWith(() => _StaticAppsNotifier([])),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: PyenvManageModal(app: app, onClose: () {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppModalHeader), findsOneWidget);
      final header = tester.widget<AppModalHeader>(find.byType(AppModalHeader));
      expect(header.title, 'Python Version Management');
      expect(header.subtitle, 'Powered by pyenv-win');
      expect(header.icon, LucideIcons.terminal);
      expect(header.iconSize, 20.0);
    });

    testWidgets('AddDatabaseModal has standard AppModalHeader', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1080, 720));
      addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

      final engine = AppModel(
        appId: 'mysql',
        name: 'MySQL',
        categories: ['database'],
        versions: ['8.0'],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appsProvider.overrideWith(() => _StaticAppsNotifier([])),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: AddDatabaseModal(engine: engine, onClose: () {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppModalHeader), findsOneWidget);
      final header = tester.widget<AppModalHeader>(find.byType(AppModalHeader));
      expect(header.title, 'Create New Database');
      expect(header.icon, LucideIcons.database);
      expect(header.iconSize, 20.0);
    });

    testWidgets('AddRedisKeyModal has standard AppModalHeader', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1080, 720));
      addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

      final engine = AppModel(
        appId: 'redis',
        name: 'Redis',
        categories: ['database'],
        versions: ['7.2'],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appsProvider.overrideWith(() => _StaticAppsNotifier([])),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: AddRedisKeyModal(engine: engine, dbIndex: 0, onClose: () {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppModalHeader), findsOneWidget);
      final header = tester.widget<AppModalHeader>(find.byType(AppModalHeader));
      expect(header.title, 'Add Redis Key (DB0)');
      expect(header.icon, LucideIcons.key);
      expect(header.iconSize, 20.0);
    });

    testWidgets('CreateTunnelModal has standard AppModalHeader', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1080, 720));
      addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appsProvider.overrideWith(() => _StaticAppsNotifier([])),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: CreateTunnelModal(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppModalHeader), findsOneWidget);
      final header = tester.widget<AppModalHeader>(find.byType(AppModalHeader));
      expect(header.title, 'Create Tunnel');
      expect(header.icon, LucideIcons.cloud);
      expect(header.iconSize, 20.0);
    });

    testWidgets('TunnelQrModal has standard AppModalHeader', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1080, 720));
      addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TunnelQrModal(
              tunnelName: 'test-tunnel',
              publicUrl: 'https://test.trycloudflare.com',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppModalHeader), findsOneWidget);
      final header = tester.widget<AppModalHeader>(find.byType(AppModalHeader));
      expect(header.title, 'test-tunnel - QR Code');
      expect(header.icon, LucideIcons.qrCode);
      expect(header.iconSize, 20.0);
    });

    testWidgets('SiteTunnelDialog has standard AppModalHeader', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1080, 720));
      addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

      final site = SiteModel(
        id: 1,
        domain: 'share.test',
        rootDir: '/var/www',
        siteType: 'php',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appsProvider.overrideWith(() => _StaticAppsNotifier([])),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SiteTunnelDialog(site: site),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppModalHeader), findsOneWidget);
      final header = tester.widget<AppModalHeader>(find.byType(AppModalHeader));
      expect(header.title, 'Share share.test');
      expect(header.icon, LucideIcons.share2);
      expect(header.iconSize, 20.0);
    });

    testWidgets('BatchProgressDialog has standard AppModalHeader', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1080, 720));
      addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

      final progress = ValueNotifier<BatchProgress>(
        const BatchProgress(
          current: 1,
          total: 5,
          currentLabel: 'Processing site 1',
          phase: BatchPhase.processing,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BatchProgressDialog(
              title: 'Batch Update Sites',
              progress: progress,
              onCancel: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppModalHeader), findsOneWidget);
      final header = tester.widget<AppModalHeader>(find.byType(AppModalHeader));
      expect(header.title, 'Batch Update Sites');
      expect(header.icon, LucideIcons.layers);
      expect(header.iconSize, 20.0);
    });
  });
}
