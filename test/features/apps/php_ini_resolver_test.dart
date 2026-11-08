import 'package:dev_stack/features/apps/data/php_settings_provider.dart';
import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  AppModel createApp({String appId = 'php82', String? location}) => AppModel(
    appId: appId,
    name: 'PHP',
    categories: ['runtime'],
    location: location,
  );

  test('Windows app resolves <location>/php.ini', () {
    final app = createApp(location: r'C:\dev-stack\apps\php\8.2');
    expect(resolvePhpIniPath(app, isLinux: false), p.join(r'C:\dev-stack\apps\php\8.2', 'php.ini'));
  });

  test('Linux app without a bundle resolves <location>/php.ini', () {
    final app = createApp(location: '/opt/custom/php82');
    expect(resolvePhpIniPath(app, isLinux: true), '/opt/custom/php82/php.ini');
  });

  test('no location resolves to null', () {
    expect(resolvePhpIniPath(createApp(), isLinux: true), isNull);
  });
}
