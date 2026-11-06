import 'dart:async';
import 'dart:io';

import 'package:dev_stack/features/apps/data/apps_provider.dart';
import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:dev_stack/features/logs/presentation/logs_page.dart';
import 'package:dev_stack/shared/widgets/terminal_log_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FailedApps extends Apps {
  @override
  Future<List<AppModel>> build() async {
    throw const FormatException('Missing catalog name');
  }
}

class _PendingApps extends Apps {
  final Future<List<AppModel>> pending;
  _PendingApps(this.pending);

  @override
  Future<List<AppModel>> build() => pending;
}

void main() {
  late Directory root;
  late File logFile;

  setUp(() {
    root = Directory.systemTemp.createTempSync('catalog_logs_');
    logFile = File('${root.path}/2026-11-06.log')
      ..writeAsStringSync('Catalog update failed: missing Redis name\n');
  });
  tearDown(() => root.deleteSync(recursive: true));

  for (final loading in [false, true]) {
    testWidgets(
      'system log files remain readable while apps are ${loading ? 'loading' : 'in error'}',
      (tester) async {
        final pending = Completer<List<AppModel>>();
        final container = ProviderContainer.test(
          retry: (retryCount, error) => null,
          overrides: [
            appsProvider.overrideWith(
              loading ? () => _PendingApps(pending.future) : _FailedApps.new,
            ),
            logFilesProvider.overrideWith((ref) async => [logFile]),
          ],
        );
        // Start real file IO outside the widget test's fake async zone.
        await tester.runAsync(() async {
          await container.read(logFileContentProvider(logFile.path).future);
        });
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: LogsPage()),
          ),
        );
        await tester.pump();

        expect(find.byType(TerminalLogView), findsOneWidget);
        final terminal = tester.widget<TerminalLogView>(
          find.byType(TerminalLogView),
        );
        expect(terminal.title, '2026-11-06.log');
        expect(terminal.lines, ['Catalog update failed: missing Redis name']);
        expect(find.text('REFRESH'), findsOneWidget);
        expect(find.text('DELETE'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
