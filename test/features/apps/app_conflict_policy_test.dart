import 'package:dev_stack/features/apps/domain/app_conflict_policy.dart';
import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:flutter_test/flutter_test.dart';

AppModel app(String id, {bool installed = false}) => AppModel(
  appId: id,
  name: id,
  categories: const ['webserver'],
  groupName: id,
  isInstalled: installed,
);

void main() {
  group('AppConflictPolicy', () {
    test('Caddy conflicts with both nginx and Apache', () {
      expect(
        AppConflictPolicy.conflictsFor(app('caddy')),
        equals({'nginx', 'apache'}),
      );
    });

    test('nginx and Apache each conflict with Caddy and one another', () {
      expect(
        AppConflictPolicy.conflictsFor(app('nginx')),
        equals({'apache', 'caddy'}),
      );
      expect(
        AppConflictPolicy.conflictsFor(app('apache')),
        equals({'nginx', 'caddy'}),
      );
    });

    test('finds either installed server conflict for Caddy', () {
      expect(
        AppConflictPolicy.firstInstalledConflict(
          app('caddy'),
          [app('apache', installed: true)],
        )?.appId,
        'apache',
      );
      expect(
        AppConflictPolicy.firstInstalledConflict(
          app('caddy'),
          [app('nginx', installed: true)],
        )?.appId,
        'nginx',
      );
    });

    test('preserves MySQL and MariaDB mutual exclusion', () {
      final mysql = AppModel(
        appId: 'mysql',
        name: 'MySQL',
        categories: const ['database'],
        groupName: 'mysql',
      );
      final maria = AppModel(
        appId: 'mariadb',
        name: 'MariaDB',
        categories: const ['database'],
        groupName: 'mariadb',
        isInstalled: true,
      );

      expect(
        AppConflictPolicy.firstInstalledConflict(mysql, [maria]),
        same(maria),
      );
    });
  });
}
