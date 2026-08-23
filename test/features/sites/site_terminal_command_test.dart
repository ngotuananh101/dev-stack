import 'package:flutter_test/flutter_test.dart';
import 'package:dev_stack/features/sites/presentation/widgets/site_table.dart';

void main() {
  group('Site Terminal Launch Spec', () {
    test('builds Windows powershell command with formatted header and PATH', () {
      final spec = SiteTable.buildTerminalLaunchSpec(
        isLinux: false,
        sitePath: r'C:\Ponta\www\test_site',
        phpDir: r'C:\Ponta\apps\php83',
        domain: 'test.local',
      );
      expect(spec.executable, equals('start'));
      expect(spec.arguments, contains('powershell'));
      expect(spec.arguments.last, contains(r'$env:PATH = "C:\Ponta\apps\php83;" + $env:PATH'));
      expect(spec.runInShell, isTrue);
    });

    test('builds Linux bash launcher command with PATH and banner', () {
      final spec = SiteTable.buildTerminalLaunchSpec(
        isLinux: true,
        sitePath: '/home/user/.ponta/www/test_site',
        phpDir: '/home/user/.ponta/apps/php83',
        domain: 'test.local',
      );
      expect(spec.executable, equals('x-terminal-emulator'));
      expect(spec.arguments, contains('-e'));
      expect(spec.arguments.last, contains('PATH="/home/user/.ponta/apps/php83:\$PATH"'));
      expect(spec.runInShell, isFalse);
    });
  });
}
