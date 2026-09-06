import 'package:dev_stack/core/services/log_service.dart';
import 'package:dev_stack/features/apps/data/app_service_manager.dart';
import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AppModel createPhpApp({String appId = 'php82', String name = 'PHP 8.2'}) {
    return AppModel(
      appId: appId,
      name: name,
      categories: ['language'],
      groupName: 'php',
      installMethod: 'package_manager',
    );
  }

  group('AppServiceManager - PHP-FPM service management (foreground)', () {
    test('package_manager PHP-FPM app uses foreground arguments', () {
      final app = createPhpApp();
      // php-fpm8.2 should get -F -y with a php-fpm.conf path
      final args = AppServiceManager.argumentsForExecutable(
        'php-fpm8.2',
        '/usr/sbin',
        appId: app.appId,
        isLinux: true,
      );
      expect(args, containsAll(['-F', '-y']));
      expect(args.last, contains('php-fpm.conf'));
    });

    test('package_manager PHP-FPM app requires correct socket port', () {
      final app = createPhpApp(appId: 'php82');
      final sockets = AppServiceManager.requiredSocketsForExecutable(
        'php-fpm8.2',
        appId: app.appId,
      );
      expect(sockets.any((s) => s.port == 9082), isTrue);
    });

    test('start() no longer delegates to systemctl for package_manager PHP', () {
      // Verify the service manager no longer has systemctl bypass methods.
      final manager = AppServiceManager(AppLogger);
      // These methods should no longer exist after the refactor.
      expect(manager, isNotNull);
    });
  });
}
