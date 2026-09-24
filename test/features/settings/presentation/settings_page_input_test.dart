import 'package:dev_stack/core/services/ssl_service.dart';
import 'package:dev_stack/features/apps/data/apps_provider.dart';
import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:dev_stack/features/settings/data/settings_provider.dart';
import 'package:dev_stack/features/settings/domain/app_settings.dart';
import 'package:dev_stack/features/settings/presentation/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class _StaticSettingsNotifier extends Settings {
  final AppSettings _settings;
  _StaticSettingsNotifier(this._settings);

  @override
  Future<AppSettings> build() => Future.value(_settings);
}

class _StaticAppsNotifier extends Apps {
  @override
  Future<List<AppModel>> build() => Future.value([]);
}

class _StaticSslService extends SslService {
  @override
  Future<bool> build() => Future.value(false);
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('SettingsPage input fields and dropdowns adhere to 280x36 standard', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

    final settings = AppSettings()..siteTemplate = '{name}.test';

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(() => _StaticSettingsNotifier(settings)),
          appsProvider.overrideWith(() => _StaticAppsNotifier()),
          sslServiceProvider.overrideWith(() => _StaticSslService()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SettingsPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Site Configuration section is rendered
    expect(find.text('Auto Create Site Template'), findsOneWidget);
    expect(find.text('Default PHP Version'), findsOneWidget);

    // 1. Verify Auto Create Site Template field has width 320 and height 36, and has globe prefix icon
    final templateFieldFinder = find.byWidgetPredicate(
      (widget) => widget is TextFormField && widget.controller?.text == '{name}.test',
    );
    expect(templateFieldFinder, findsOneWidget);
    expect(
      find.descendant(
        of: templateFieldFinder,
        matching: find.byIcon(LucideIcons.globe),
      ),
      findsOneWidget,
    );

    final templateSizedBoxFinder = find.ancestor(
      of: templateFieldFinder,
      matching: find.byType(SizedBox),
    );
    final templateSizedBox = tester.widget<SizedBox>(templateSizedBoxFinder.first);
    expect(templateSizedBox.width, equals(320.0));
    expect(templateSizedBox.height, equals(36.0));

    // 2. Verify Default PHP Version dropdown container has width 320 and height 36
    final dropdownFinder = find.byType(DropdownButton<String>);
    expect(dropdownFinder, findsOneWidget);

    final dropdownContainerFinder = find.ancestor(
      of: dropdownFinder,
      matching: find.byType(Container),
    );
    final renderBox = tester.renderObject<RenderBox>(dropdownContainerFinder.first);
    expect(renderBox.size.width, equals(320.0));
    expect(renderBox.size.height, equals(36.0));
  });
}
