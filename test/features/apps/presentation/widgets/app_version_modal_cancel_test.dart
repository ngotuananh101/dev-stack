import 'package:dev_stack/features/apps/data/app_version_provider.dart';
import 'package:dev_stack/features/apps/data/apps_provider.dart';
import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:dev_stack/features/apps/presentation/widgets/app_version_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _StaticAppsNotifier extends Apps {
  final List<AppModel> _apps;
  _StaticAppsNotifier(this._apps);

  @override
  Future<List<AppModel>> build() => Future.value(_apps);
}

class _StaticVersions extends AppVersions {
  @override
  Future<AppVersionInfo> build(String appId) => Future.value(
        const AppVersionInfo(
          name: 'Test App',
          versions: ['latest', '1.0.0'],
          downloadUrls: {},
        ),
      );
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  AppModel installingApp() {
    final app = AppModel(
      appId: 'testapp',
      name: 'Test App',
      categories: const ['tools'],
      status: 'installing',
      installProgress: 0.4,
      installStatus: 'Downloading...',
    );
    app.installLogs = ['Starting installation...'];
    return app;
  }

  testWidgets('AppVersionModal shows a Cancel button while installing', (tester) async {
    var cancelled = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appsProvider.overrideWith(() => _StaticAppsNotifier([installingApp()])),
          appVersionsProvider.overrideWith2((_) => _StaticVersions()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppVersionModal(
                app: installingApp(),
                onInstall: () {},
                onClose: () {},
                onCancel: () => cancelled = true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final cancelButton = find.text('Cancel');
    expect(cancelButton, findsOneWidget);
    expect(find.text('Installing...'), findsNothing);

    await tester.tap(cancelButton);
    expect(cancelled, isTrue);
  });

  testWidgets('AppVersionModal shows Finish (not Cancel) once installed', (tester) async {
    final installed = AppModel(
      appId: 'testapp',
      name: 'Test App',
      categories: const ['tools'],
      status: 'installed',
      isInstalled: true,
    );
    installed.installLogs = ['Done'];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appsProvider.overrideWith(() => _StaticAppsNotifier([installed])),
          appVersionsProvider.overrideWith2((_) => _StaticVersions()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppVersionModal(
                app: installed,
                onInstall: () {},
                onClose: () {},
                onCancel: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Finish'), findsOneWidget);
    expect(find.text('Cancel'), findsNothing);
  });
}
