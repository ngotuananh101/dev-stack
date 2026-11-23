import 'dart:async';
import 'dart:io';

import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:dev_stack/features/databases/data/redis_provider.dart';
import 'package:dev_stack/features/databases/presentation/widgets/redis_explorer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

AppModel _redisApp() => AppModel(
  appId: 'redis',
  name: 'Redis',
  categories: const ['database'],
  isInstalled: true,
  status: 'installed',
  cliFilePath: '/fake/redis-cli',
);

ProcessResult _ok(String stdout, [String stderr = '']) =>
    ProcessResult(0, 0, stdout, stderr);

class _Harness extends StatefulWidget {
  final AppModel app;

  const _Harness({required this.app});

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  String searchQuery = '';
  int selectedDb = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            TextField(
              key: const Key('search'),
              onChanged: (value) => setState(() => searchQuery = value),
            ),
            TextButton(
              key: const Key('db1'),
              onPressed: () => setState(() => selectedDb = 1),
              child: const Text('DB1'),
            ),
            Expanded(
              child: RedisExplorer(
                app: widget.app,
                searchQuery: searchQuery,
                selectedDb: selectedDb,
                onDbChanged: (db) => setState(() => selectedDb = db),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  testWidgets(
    'debounces search, fetches immediately on init/db switch, and ignores stale results',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final originalRunner = Redis.processRunner;
      addTearDown(() => Redis.processRunner = originalRunner);

      final firstDb0Completer = Completer<ProcessResult>();
      final scanLog = <String>[];
      Redis.processRunner = (exe, args) async {
        if (args.contains('INFO')) {
          return _ok('db0:keys=1,expires=0\ndb1:keys=1,expires=0\n');
        }
        if (args.contains('SCAN')) {
          final db = args[1];
          final pattern = args[5];
          scanLog.add('$db|$pattern');
          if (db == '0' && pattern == '*') {
            if (scanLog.where((e) => e == '0|*').length == 1) {
              return firstDb0Completer.future;
            }
            return _ok('0\nslow\n');
          }
          if (db == '0' && pattern == '*ab*') {
            return _ok('0\nab-key\n');
          }
          if (db == '1' && pattern == '*abc*') {
            return _ok('0\ndb1-key\n');
          }
          return _ok('0\n');
        }
        if (args.contains('TYPE')) return _ok('string\n');
        if (args.contains('TTL')) return _ok('-1\n');
        if (args.contains('GET')) return _ok('value\n');
        return _ok('');
      };

      await tester.pumpWidget(ProviderScope(child: _Harness(app: _redisApp())));
      await tester.pump();
      // Initial load is not debounced.
      expect(scanLog.where((e) => e == '0|*'), hasLength(1));

      await tester.enterText(find.byKey(const Key('search')), 'a');
      await tester.pump();
      firstDb0Completer.complete(_ok('9\nslow\n'));
      await tester.pump(const Duration(milliseconds: 100));
      // The old scan must stop even before the debounced replacement starts.
      expect(scanLog, ['0|*']);
      expect(find.text('slow'), findsNothing);

      await tester.enterText(find.byKey(const Key('search')), 'ab');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 299));
      expect(scanLog, ['0|*']);

      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(scanLog, ['0|*', '0|*ab*']);
      expect(find.text('ab-key'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('search')), 'abc');
      await tester.pump();
      await tester.tap(find.byKey(const Key('db1')));
      await tester.pump();
      // DB switch uses the current filter without waiting for its timer.
      expect(scanLog, ['0|*', '0|*ab*', '1|*abc*']);
      await tester.pump(const Duration(milliseconds: 300));
      expect(scanLog, ['0|*', '0|*ab*', '1|*abc*']);
      expect(find.text('db1-key'), findsOneWidget);
      expect(find.text('ab-key'), findsNothing);

      await tester.enterText(find.byKey(const Key('search')), 'abcd');
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 300));
      expect(scanLog, ['0|*', '0|*ab*', '1|*abc*']);
    },
  );
}
