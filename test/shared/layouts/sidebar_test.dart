// test/shared/layouts/sidebar_test.dart
import 'package:dev_stack/shared/layouts/sidebar.dart';
import 'package:dev_stack/shared/providers/navigation_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('NavigationTab exposes the supervisor and cron tabs', () {
    expect(NavigationTab.values, contains(NavigationTab.supervisor));
    expect(NavigationTab.values, contains(NavigationTab.cron));
  });

  testWidgets('the sidebar renders Supervisor and Cron entries',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: Sidebar())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Supervisor'), findsOneWidget);
    expect(find.text('Cron'), findsOneWidget);
  });
}
