import 'package:dev_stack/features/apps/data/app_installer_service.dart';
import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:flutter_test/flutter_test.dart';

AppModel app(String id, {String? group}) => AppModel(
  appId: id,
  name: id,
  categories: const ['webserver'],
  groupName: group,
);

void main() {
  test('installer recognizes Caddy as a managed web server', () {
    expect(
      AppInstallerService.isWebserverApp(app('caddy', group: 'webserver')),
      isTrue,
    );
    expect(AppInstallerService.isWebserverApp(app('nginx')), isTrue);
    expect(AppInstallerService.isWebserverApp(app('apache')), isTrue);
    expect(
      AppInstallerService.isWebserverApp(app('redis', group: 'redis')),
      isFalse,
    );
  });
}
