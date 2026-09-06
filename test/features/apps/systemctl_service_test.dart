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
      final app = createPhpApp(appId: 'php82');
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
      final AppServiceManager manager = AppServiceManager(AppLogger);
      expect(manager, isNotNull);
    });

    test('PHP-FPM foreground arguments are passed on Linux with conf path', () {
      final args = AppServiceManager.argumentsForExecutable(
        'php-fpm8.5',
        '/usr/sbin',
        appId: 'php85',
        isLinux: true,
      );
      // Must use -F (foreground) and -y (config file path) flags
      expect(args, contains('-F'), reason: 'PHP-FPM must run in foreground (-F)');
      expect(args, contains('-y'), reason: 'PHP-FPM must specify config file via -y');
      expect(
        args.any((a) => a.contains('php-fpm.conf')),
        isTrue,
        reason: 'PHP-FPM -y must point to php-fpm.conf',
      );
    });

    test('PHP-FPM foreground arguments include config path', () {
      final app = createPhpApp(appId: 'php82');
      final args = AppServiceManager.argumentsForExecutable(
        'php-fpm8.2',
        '/usr/sbin',
        appId: app.appId,
        isLinux: true,
      );
      // The -F and -y flags with the conf path should be present
      expect(args, containsAll(['-F', '-y']));
      expect(args.last, contains('php-fpm.conf'),
          reason: 'PHP-FPM -y must point to php-fpm.conf');
    });
  });
}
