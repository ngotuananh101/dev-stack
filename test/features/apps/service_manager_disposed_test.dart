import 'package:dev_stack/features/apps/data/app_service_manager.dart';
import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:dev_stack/core/services/log_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppServiceManager disposed-guard', () {
    test('finalizeExit returns true and mutates app when not disposed', () {
      final manager = AppServiceManager(AppLogger);
      final app = AppModel(
        appId: 'php82',
        name: 'PHP 8.2',
        categories: const ['language'],
      );

      final ran = manager.finalizeExitForTest(
        appId: 'php82',
        activeApp: app,
        onStatusChange: () {},
      );

      expect(ran, isTrue);
      expect(app.serviceStatus, 'stopped');
      expect(app.servicePid, isNull);
    });

    test('finalizeExit is a no-op after dispose (returns false)', () {
      final manager = AppServiceManager(AppLogger);
      final app = AppModel(
        appId: 'php82',
        name: 'PHP 8.2',
        categories: const ['language'],
      );

      manager.markDisposedForTest();
      var called = false;
      final ran = manager.finalizeExitForTest(
        appId: 'php82',
        activeApp: app,
        onStatusChange: () => called = true,
      );

      expect(ran, isFalse);
      expect(
        called,
        isFalse,
        reason: 'onStatusChange must not fire after dispose',
      );
    });
  });
}
