import 'package:dev_stack/features/apps/data/app_version_provider.dart';
import 'package:dev_stack/features/apps/data/apps_provider.dart';
import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:dev_stack/features/apps/presentation/widgets/app_version_modal.dart';
import 'package:dev_stack/shared/widgets/app_button.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Apps extends Apps {
  final AppModel app;
  _Apps(this.app);
  @override
  Future<List<AppModel>> build() async => [app];
}

class _Versions extends AppVersions {
  final AppVersionInfo info;
  _Versions(this.info);
  @override
  Future<AppVersionInfo> build(String appId) async => info;
}

void main() {
  for (final missing in [true, false]) {
    testWidgets(
      missing
          ? 'empty catalog disables installation'
          : 'selecting a downloadable patch enables installation',
      (tester) async {
        final app = AppModel(
          appId: 'php84',
          name: 'PHP 8.4',
          categories: ['runtime'],
        );
        var installed = false;
        final info = AppVersionInfo(
          name: app.name,
          versions: missing ? [] : ['8.4.27'],
          downloadUrls: missing
              ? {}
              : {'8.4.27': 'https://example.test/php.tar.gz'},
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appsProvider.overrideWith(() => _Apps(app)),
              appVersionsProvider.overrideWith2((_) => _Versions(info)),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: Center(
                  child: AppVersionModal(
                    app: app,
                    onInstall: () => installed = true,
                    onClose: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final installButton = find.byWidgetPredicate(
          (w) => w is AppButton && w.label.startsWith('Install '),
        );
        if (missing) {
          expect(installButton, findsNothing);
          expect(
            find.text('No downloadable versions available.'),
            findsOneWidget,
          );
        } else {
          await tester.tap(find.text('8.4.27'));
          await tester.pump();
          expect(tester.widget<AppButton>(installButton).onPressed, isNotNull);
          await tester.tap(installButton);
          expect(installed, isTrue);
          expect(app.selectedVersion, '8.4.27');
        }
      },
    );
  }

  // Review Focus 5: the catalog has downloadable versions, but the one
  // picked has no download URL, so the Install button renders disabled
  // instead of disappearing.
  testWidgets(
    'selecting a version without a download URL keeps Install disabled',
    (tester) async {
      final app = AppModel(
        appId: 'php84',
        name: 'PHP 8.4',
        categories: ['runtime'],
      );
      var installed = false;
      final info = AppVersionInfo(
        name: app.name,
        versions: ['8.4.27', '8.4.26'],
        downloadUrls: {'8.4.26': 'https://example.test/php.tar.gz'},
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appsProvider.overrideWith(() => _Apps(app)),
            appVersionsProvider.overrideWith2((_) => _Versions(info)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: AppVersionModal(
                  app: app,
                  onInstall: () => installed = true,
                  onClose: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('No downloadable versions available.'),
        findsNothing,
      );

      await tester.tap(find.text('8.4.27'));
      await tester.pump();
      final installButton = find.byWidgetPredicate(
        (w) => w is AppButton && w.label.startsWith('Install '),
      );
      expect(installButton, findsOneWidget);
      expect(tester.widget<AppButton>(installButton).onPressed, isNull);

      await tester.tap(installButton);
      expect(installed, isFalse);
    },
  );
}
