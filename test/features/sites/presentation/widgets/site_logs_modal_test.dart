import 'package:dev_stack/features/sites/data/cli_process_manager.dart';
import 'package:dev_stack/features/sites/domain/site_model.dart';
import 'package:dev_stack/features/sites/presentation/widgets/site_logs_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('SiteLogsModal displays site domain and action buttons', (tester) async {
    final site = SiteModel(
      id: 1,
      domain: 'my-cli-app.test',
      rootDir: '/test',
      siteType: 'cli',
      command: 'npm run dev',
      port: 3000,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SiteLogsModal(site: site),
          ),
        ),
      ),
    );

    expect(find.text('Logs: my-cli-app.test'), findsOneWidget);
    expect(find.byIcon(Icons.clear_all), findsOneWidget);
    expect(find.byIcon(Icons.copy), findsOneWidget);
  });
}
