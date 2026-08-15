import 'package:dev_stack/core/config/app_config.dart';
import 'package:dev_stack/features/sites/data/sites_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('Caddy vhost file policy', () {
    test('Caddy is an editable webserver config type', () {
      expect(
        SitesNotifier.editableWebserverTypes,
        equals({'nginx', 'apache', 'caddy'}),
      );
    });

    test('resolves Caddy config inside the managed vhosts directory', () {
      expect(
        SitesNotifier.vhostConfigPath('caddy', 'example.test'),
        p.join(AppConfig.vhostsDir, 'caddy', 'example.test.conf'),
      );
    });

    test('rejects unknown config types and traversal domains', () {
      expect(
        () => SitesNotifier.vhostConfigPath('iis', 'example.test'),
        throwsArgumentError,
      );
      expect(
        () => SitesNotifier.vhostConfigPath('caddy', '../escape'),
        throwsArgumentError,
      );
    });
  });
}
