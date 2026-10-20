import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:dev_stack/features/apps/presentation/widgets/compact_apps_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

void main() {
  AppModel app({String appId = 'php'}) => AppModel(
        appId: appId,
        name: 'PHP 8.3',
        description: 'PHP interpreter',
        categories: const ['webserver'],
        versions: const ['8.3.0'],
        isInstalled: true,
      );

  Widget host(double width, List<AppModel> apps) => MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              Expanded(
                child: CompactAppsTable(
                  apps: apps,
                  onToggleInstall: (_) async {},
                  onTogglePath: (_) async {},
                  onStartService: (_) async {},
                  onStopService: (_) async {},
                  onRestartService: (_) async {},
                  onChangeDefault: (_) async {},
                  onOpen: (_) async {},
                  onCancelInstall: (_) {},
                ),
              ),
            ]),
          ),
        ),
      );

  testWidgets('renders every action inline when the row is wide',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 720));
    addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

    await tester.pumpWidget(host(1600, [app()]));
    await tester.pumpAndSettle();

    expect(find.byIcon(LucideIcons.moreHorizontal), findsNothing);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
  });

  testWidgets('collapses actions into one menu at a ~412px row',
      (tester) async {
    // A 700px window leaves ~412px here — narrower than the row's fixed
    // columns plus the ~164px action cluster it used to lay out inside a
    // rigid 140px box.
    await tester.binding.setSurfaceSize(const Size(700, 720));
    addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

    await tester.pumpWidget(host(700, [app()]));
    await tester.pumpAndSettle();

    // Reaching this pump without a RenderFlex overflow means the row fits.
    expect(find.byIcon(LucideIcons.moreHorizontal), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsNothing);

    await tester.tap(find.byIcon(LucideIcons.moreHorizontal));
    await tester.pumpAndSettle();

    expect(find.text('View Logs'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Uninstall'), findsOneWidget);
  });
}
