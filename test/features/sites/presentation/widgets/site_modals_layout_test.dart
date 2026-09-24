import 'package:dev_stack/core/theme/app_colors.dart';
import 'package:dev_stack/features/apps/data/apps_provider.dart';
import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:dev_stack/features/sites/domain/site_model.dart';
import 'package:dev_stack/features/sites/presentation/widgets/add_site_modal.dart';
import 'package:dev_stack/features/sites/presentation/widgets/edit_site_modal.dart';
import 'package:dev_stack/shared/widgets/code_editor/config_code_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _StaticAppsNotifier extends Apps {
  final List<AppModel> _apps;
  _StaticAppsNotifier(this._apps);

  @override
  Future<List<AppModel>> build() => Future.value(_apps);
}

void main() {
  testWidgets('AddSiteModal and EditSiteModal have unified width 620 and surface background', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1080, 720));
    addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

    // 1. Check AddSiteModal
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

    // Find outer modal container for AddSiteModal
    final addModalContainerFinder = find.byWidgetPredicate(
      (w) => w is Container && (w.decoration is BoxDecoration) && (w.decoration as BoxDecoration).color == AppColors.surface,
    );
    expect(addModalContainerFinder, findsWidgets);

    final addModalContainer = tester.widget<Container>(addModalContainerFinder.first);
    expect(addModalContainer.constraints?.maxWidth ?? 0, 620.0);
    final addBoxDecoration = addModalContainer.decoration as BoxDecoration;
    expect(addBoxDecoration.color, AppColors.surface);

    // 2. Check EditSiteModal
    final site = SiteModel(
      id: 1,
      domain: 'my-project.test',
      rootDir: '/projects/my-project',
      siteType: 'php',
      phpVersion: '8.2',
      useSsl: true,
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

    final editModalFinder = find.byType(Dialog);
    expect(editModalFinder, findsOneWidget);

    final editContainerFinder = find.byWidgetPredicate(
      (w) => w is Container && (w.decoration is BoxDecoration) && (w.decoration as BoxDecoration).color == AppColors.surface,
    );
    expect(editContainerFinder, findsWidgets);

    final editModalContainer = tester.widget<Container>(editContainerFinder.first);
    expect(editModalContainer.constraints?.maxWidth ?? 0, 620.0);
    final editBoxDecoration = editModalContainer.decoration as BoxDecoration;
    expect(editBoxDecoration.color, AppColors.surface);

    // Verify all 4 tabs switch without overflow
    expect(find.widgetWithText(Tab, 'General'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Config'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'SSL'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Logs'), findsOneWidget);

    // Switch to Config tab
    await tester.tap(find.widgetWithText(Tab, 'Config'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.byType(ConfigCodeEditor), findsOneWidget);

    // Switch to SSL tab
    await tester.tap(find.widgetWithText(Tab, 'SSL'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    expect(find.text('Certificate'), findsOneWidget);
    expect(find.text('Private Key'), findsOneWidget);
    expect(find.text('Regenerate SSL'), findsOneWidget);
    expect(find.text('Save Changes'), findsOneWidget);

    // Switch to Logs tab
    await tester.tap(find.widgetWithText(Tab, 'Logs'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    expect(find.byType(ConfigCodeEditor), findsOneWidget);
  });

  testWidgets('EditSiteModal Logs tab displays only logs of installed webserver', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1080, 720));
    addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

    final site = SiteModel(
      id: 1,
      domain: 'my-project.test',
      rootDir: '/projects/my-project',
      siteType: 'php',
      phpVersion: '8.2',
      useSsl: true,
    );

    final nginxApp = AppModel(
      appId: 'nginx',
      name: 'Nginx',
      categories: ['webserver'],
      versions: ['1.24'],
    )..isInstalled = true;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appsProvider.overrideWith(() => _StaticAppsNotifier([nginxApp])),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: EditSiteModal(site: site, onClose: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Switch to Logs tab
    await tester.tap(find.widgetWithText(Tab, 'Logs'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);

    // Should only have Nginx logs
    expect(find.text('Nginx Access'), findsOneWidget);
    expect(find.text('Nginx Error'), findsOneWidget);
    expect(find.text('Apache Access'), findsNothing);
    expect(find.text('Caddy Access'), findsNothing);
    expect(find.byType(ConfigCodeEditor), findsOneWidget);
    expect(find.text('nginx_access.log'), findsOneWidget);

    // Switching between Nginx Access and Nginx Error works
    await tester.tap(find.text('Nginx Error'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.text('nginx_error.log'), findsOneWidget);
  });

  testWidgets('EditSiteModal Logs tab displays only Apache logs when only Apache is installed', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1080, 720));
    addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

    final site = SiteModel(
      id: 1,
      domain: 'my-project.test',
      rootDir: '/projects/my-project',
      siteType: 'php',
      phpVersion: '8.2',
      useSsl: true,
    );

    final apacheApp = AppModel(
      appId: 'apache',
      name: 'Apache',
      categories: ['webserver'],
      versions: ['2.4'],
    )..isInstalled = true;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appsProvider.overrideWith(() => _StaticAppsNotifier([apacheApp])),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: EditSiteModal(site: site, onClose: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Switch to Logs tab
    await tester.tap(find.widgetWithText(Tab, 'Logs'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);

    // Should only have Apache logs
    expect(find.text('Apache Access'), findsOneWidget);
    expect(find.text('Apache Error'), findsOneWidget);
    expect(find.text('Nginx Access'), findsNothing);
    expect(find.text('Caddy Access'), findsNothing);
    expect(find.byType(ConfigCodeEditor), findsOneWidget);
    expect(find.text('apache_access.log'), findsOneWidget);
  });

  testWidgets('EditSiteModal Config tab switches between webservers in CodeEditor', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1080, 720));
    addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

    final site = SiteModel(
      id: 1,
      domain: 'my-project.test',
      rootDir: '/projects/my-project',
      siteType: 'php',
      phpVersion: '8.2',
      useSsl: true,
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

    // Switch to Config tab
    await tester.tap(find.widgetWithText(Tab, 'Config'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);

    // Initial is Nginx
    expect(find.byType(ConfigCodeEditor), findsOneWidget);
    final nginxEditor = tester.widget<ConfigCodeEditor>(find.byType(ConfigCodeEditor));
    expect(nginxEditor.filePath.toLowerCase().contains('nginx'), isTrue);

    // Switch to Apache
    await tester.tap(find.text('Apache'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    final apacheEditor = tester.widget<ConfigCodeEditor>(find.byType(ConfigCodeEditor));
    expect(apacheEditor.filePath.toLowerCase().contains('apache'), isTrue);

    // Switch to Caddy
    await tester.tap(find.text('Caddy'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    final caddyEditor = tester.widget<ConfigCodeEditor>(find.byType(ConfigCodeEditor));
    expect(caddyEditor.filePath.toLowerCase().contains('caddy'), isTrue);
  });
}
