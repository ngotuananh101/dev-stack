import 'dart:async';

import 'package:dev_stack/features/apps/data/apps_provider.dart';
import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:dev_stack/features/databases/data/databases_provider.dart';
import 'package:dev_stack/features/databases/domain/database_record.dart';
import 'package:dev_stack/features/databases/presentation/databases_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _StaticAppsNotifier extends Apps {
  final List<AppModel> _apps;
  _StaticAppsNotifier(this._apps);

  @override
  Future<List<AppModel>> build() => Future.value(_apps);
}

class _StaticDatabasesNotifier extends Databases {
  @override
  FutureOr<List<DatabaseRecord>> build() => [];

  @override
  Future<void> fetchByEngine(String engineAppId) async {
    state = const AsyncValue.data([]);
  }
}

AppModel _engine(String id, String name) => AppModel(
  appId: id,
  name: name,
  categories: ['database'],
  isInstalled: true,
  status: 'installed',
  installedVersion: '1.0.0',
);

AppModel _phpMyAdmin() => AppModel(
  appId: 'phpMyAdmin',
  name: 'phpMyAdmin',
  categories: ['tool'],
  isInstalled: true,
  status: 'installed',
);

Future<void> _pumpPage(
  WidgetTester tester, {
  required AppModel engine,
  required bool phpMyAdminInstalled,
}) async {
  await tester.binding.setSurfaceSize(const Size(1400, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final apps = <AppModel>[
    engine,
    if (phpMyAdminInstalled) _phpMyAdmin(),
  ];

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appsProvider.overrideWith(() => _StaticAppsNotifier(apps)),
        databasesProvider.overrideWith(_StaticDatabasesNotifier.new),
      ],
      child: const MaterialApp(home: Scaffold(body: DatabasesPage())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => TestWidgetsFlutterBinding.ensureInitialized());

  group('DatabasesPage phpMyAdmin action button', () {
    testWidgets('hidden for PostgreSQL even when phpMyAdmin is installed', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        engine: _engine('postgresql', 'PostgreSQL'),
        phpMyAdminInstalled: true,
      );

      expect(find.text('PostgreSQL'), findsWidgets);
      expect(find.text('phpMyAdmin'), findsNothing);
    });

    testWidgets('hidden for Meilisearch even when phpMyAdmin is installed', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        engine: _engine('meilisearch', 'Meilisearch'),
        phpMyAdminInstalled: true,
      );

      expect(find.text('phpMyAdmin'), findsNothing);
    });

    testWidgets('shown for MySQL when phpMyAdmin is installed', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        engine: _engine('mysql', 'MySQL'),
        phpMyAdminInstalled: true,
      );

      expect(find.text('phpMyAdmin'), findsOneWidget);
    });

    testWidgets('shown for MariaDB when phpMyAdmin is installed', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        engine: _engine('mariadb', 'MariaDB'),
        phpMyAdminInstalled: true,
      );

      expect(find.text('phpMyAdmin'), findsOneWidget);
    });

    testWidgets('hidden for MySQL when phpMyAdmin is not installed', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        engine: _engine('mysql', 'MySQL'),
        phpMyAdminInstalled: false,
      );

      expect(find.text('phpMyAdmin'), findsNothing);
    });
  });

  group('DatabasesPage narrow toolbar', () {
    testWidgets('fits a narrow window without an overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(560, 720));
      addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appsProvider.overrideWith(
              () => _StaticAppsNotifier([
                _engine('mysql', 'MySQL'),
                _phpMyAdmin(),
              ]),
            ),
            databasesProvider.overrideWith(_StaticDatabasesNotifier.new),
          ],
          child: const MaterialApp(home: Scaffold(body: DatabasesPage())),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      final searchWidth = tester.getSize(find.byType(TextField).first).width;
      expect(searchWidth, lessThan(280));
      expect(find.text('Add DB'), findsOneWidget);
      expect(find.text('phpMyAdmin'), findsOneWidget);
    });
  });
}
