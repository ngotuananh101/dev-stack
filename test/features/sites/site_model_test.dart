import 'package:dev_stack/features/sites/domain/site_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SiteModel CLI fields', () {
    test('instantiates SiteModel with CLI fields', () {
      final site = SiteModel(
        domain: 'myapp.test',
        rootDir: '/path/to/app',
        siteType: 'cli',
        command: 'npm run dev',
        port: 3000,
        autoStart: true,
        useSsl: true,
      );

      expect(site.domain, 'myapp.test');
      expect(site.rootDir, '/path/to/app');
      expect(site.siteType, 'cli');
      expect(site.command, 'npm run dev');
      expect(site.port, 3000);
      expect(site.autoStart, isTrue);
      expect(site.useSsl, isTrue);
    });

    test('default autoStart is false and command/port are nullable', () {
      final site = SiteModel(
        domain: 'static.test',
        rootDir: '/path/to/static',
        siteType: 'static',
      );

      expect(site.autoStart, isFalse);
      expect(site.command, isNull);
      expect(site.port, isNull);
    });
  });
}
