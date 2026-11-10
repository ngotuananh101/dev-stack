import 'package:dev_stack/core/config/apache_config_builder.dart';
import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:dev_stack/features/apps/presentation/widgets/app_settings_modal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final apache = AppModel(
    appId: 'apache',
    name: 'Apache',
    categories: const ['webserver'],
    groupName: 'webserver',
  );

  test(
    'Apache config tab label on Linux names the generated isolated file',
    () {
      expect(
        webserverConfigTabLabel(apache, isLinux: true),
        ApacheConfigBuilder.mainConfigFileName,
      );
      // Pinned literally too: the editor opens `_httpd.conf`, not `httpd.conf`.
      expect(webserverConfigTabLabel(apache, isLinux: true), '_httpd.conf');
    },
  );

  test('Apache config tab label on Windows keeps the bundle literal', () {
    expect(webserverConfigTabLabel(apache, isLinux: false), 'httpd.conf');
  });
}
