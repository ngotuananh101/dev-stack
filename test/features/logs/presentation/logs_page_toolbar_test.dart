import 'dart:io';

import 'package:dev_stack/features/apps/data/apps_provider.dart';
import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:dev_stack/features/logs/presentation/logs_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _StaticAppsNotifier extends Apps {
  @override
  Future<List<AppModel>> build() async => [
        AppModel(
          appId: 'mysql',
          name: 'MySQL',
          categories: const ['database'],
          isInstalled: true,
          status: 'installed',
          installedVersion: '8.0',
        ),
      ];
}

void main() {
  testWidgets('logs toolbar keeps the dropdown and the buttons reachable',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(560, 720));
    addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appsProvider.overrideWith(_StaticAppsNotifier.new),
          logFilesProvider.overrideWith((ref) async => <File>[]),
        ],
        child: const MaterialApp(home: Scaffold(body: LogsPage())),
      ),
    );
    await tester.pumpAndSettle();

    // A layout overflow reaching this point is the proof the toolbar no longer
    // fits a narrow window: the dropdown used to collapse to nothing while the
    // action buttons were pushed out of view.
    expect(tester.takeException(), isNull);

    final dropdownWidth = tester.getSize(find.byType(DropdownButton<String>)).width;
    expect(dropdownWidth, greaterThan(0));
    expect(find.text('REFRESH'), findsOneWidget);
    expect(find.text('CLEAR'), findsOneWidget);
  });
}
