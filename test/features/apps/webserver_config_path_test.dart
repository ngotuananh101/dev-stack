import 'package:dev_stack/features/apps/data/webserver_settings_provider.dart';
import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('resolves Caddyfile at the Caddy install root', () {
    final app = AppModel(
      appId: 'caddy',
      name: 'Caddy',
      categories: const ['webserver'],
      groupName: 'webserver',
      location: r'C:\Ponta\apps\caddy\2.11.4',
    );

    expect(
      webserverConfigFileFor(app)?.path,
      p.join(r'C:\Ponta\apps\caddy\2.11.4', 'Caddyfile'),
    );
  });
}
