import 'package:flutter_test/flutter_test.dart';
import 'package:dev_stack/features/apps/data/app_installer_service.dart';

void main() {
  group('Apache phpMyAdmin configuration', () {
    test('generates valid alias and FastCGI handler block', () {
      const pmaPathUnix = '/opt/ponta/apps/phpmyadmin';
      final config = AppInstallerService.buildApachePmaConfig(pmaPathUnix, phpPort: 9000);
      expect(config, contains('Alias /phpmyadmin "$pmaPathUnix/"'));
      expect(config, contains('<Directory "$pmaPathUnix/">'));
      expect(config, contains(r'<FilesMatch \.php$>'));
      expect(config, contains('SetHandler "proxy:fcgi://127.0.0.1:9000"'));
    });
  });
}
