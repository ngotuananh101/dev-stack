import 'package:dev_stack/features/apps/data/apps_provider.dart';
import 'package:dev_stack/features/apps/data/php_settings_provider.dart';
import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:dev_stack/features/apps/presentation/widgets/app_settings_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _StaticAppsNotifier extends Apps {
  @override
  Future<List<AppModel>> build() => Future.value([]);
}

class _MockPhpSettings extends PhpSettings {
  final List<PhpExtension> _exts;
  _MockPhpSettings(this._exts);

  @override
  Future<List<PhpExtension>> getExtensions(AppModel app, [String? iniContent]) async {
    return _exts;
  }
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('AppSettingsModal renders compact PHP extension cards', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

    final phpApp = AppModel(
      appId: 'php82',
      name: 'PHP 8.2',
      categories: ['runtime'],
      groupName: 'php',
      versions: ['8.2.10'],
      location: 'C:\\php82',
      isInstalled: true,
    );

    final mockExtensions = [
      PhpExtension(
        name: 'curl',
        fileName: 'php_curl.dll',
        isEnabled: true,
        isFoundInIni: true,
        isZend: false,
      ),
      PhpExtension(
        name: 'mbstring',
        fileName: 'php_mbstring.dll',
        isEnabled: false,
        isFoundInIni: true,
        isZend: false,
      ),
      PhpExtension(
        name: 'opcache',
        fileName: 'php_opcache.dll',
        isEnabled: true,
        isFoundInIni: true,
        isZend: true,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appsProvider.overrideWith(() => _StaticAppsNotifier()),
          phpSettingsProvider.overrideWith(() => _MockPhpSettings(mockExtensions)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppSettingsModal(
                app: phpApp,
                onClose: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Edit Config button in header should be removed
    expect(find.text('Edit Config'), findsNothing);

    // Switch to Extensions tab (index 2 for PHP with config tab)
    final extensionsTab = find.text('Extensions');
    expect(extensionsTab, findsOneWidget);
    await tester.tap(extensionsTab);
    await tester.pumpAndSettle();

    // Verify extension names are present
    expect(find.text('curl'), findsOneWidget);
    expect(find.text('mbstring'), findsOneWidget);

    // Extension cards should be compact (height <= 50px, width <= 300px)
    final curlCardFinder = find.ancestor(
      of: find.text('curl'),
      matching: find.byType(Container),
    ).first;
    final cardSize = tester.getSize(curlCardFinder);
    expect(cardSize.height, lessThanOrEqualTo(50.0));
    expect(cardSize.width, lessThanOrEqualTo(300.0));

    // Redundant 'Standard extension' subtitle should be removed for compactness
    expect(find.text('Standard extension'), findsNothing);
  });
}
