import 'package:dev_stack/core/theme/app_text_size.dart';
import 'package:dev_stack/features/apps/data/apps_provider.dart';
import 'package:dev_stack/features/apps/data/php_settings_provider.dart';
import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:dev_stack/features/apps/presentation/widgets/app_settings_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class _StaticAppsNotifier extends Apps {
  @override
  Future<List<AppModel>> build() => Future.value([]);
}

class _MockPhpSettings extends PhpSettings {
  @override
  Future<List<PhpExtension>> getExtensions(AppModel app, [String? iniContent]) async {
    return [];
  }
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('AppSettingsModal Service tab inputs have standard 36px height, xs label, and prefix icons', (tester) async {
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
      extraInfoJson: '{"bind_address": "127.0.0.1", "port": "9000"}',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appsProvider.overrideWith(() => _StaticAppsNotifier()),
          phpSettingsProvider.overrideWith(() => _MockPhpSettings()),
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

    // Verify Service tab is visible and has Startup Configuration
    expect(find.text('Startup Configuration'), findsOneWidget);
    expect(find.text('Bind Address'), findsOneWidget);
    expect(find.text('Port'), findsOneWidget);

    // Verify Label styling: fontSize should be AppTextSize.xs (12px), fontWeight: FontWeight.w600
    final bindLabelText = tester.widget<Text>(find.text('Bind Address'));
    expect(bindLabelText.style?.fontSize, equals(AppTextSize.xs));
    expect(bindLabelText.style?.fontWeight, equals(FontWeight.w600));

    // Verify TextFormField is enclosed in a SizedBox of height 36
    final formFields = find.byType(TextFormField);
    expect(formFields, findsAtLeastNWidgets(2));

    for (final field in formFields.evaluate()) {
      final sizedBoxFinder = find.ancestor(
        of: find.byWidget(field.widget),
        matching: find.byType(SizedBox),
      );
      final sizedBox = tester.widget<SizedBox>(sizedBoxFinder.first);
      expect(sizedBox.height, equals(36.0));
    }

    // Verify prefix icons
    expect(find.byIcon(LucideIcons.network), findsOneWidget);
    expect(find.byIcon(LucideIcons.hash), findsOneWidget);
  });
}
