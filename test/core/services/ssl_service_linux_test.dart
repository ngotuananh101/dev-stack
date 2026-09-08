import 'package:flutter_test/flutter_test.dart';
import 'package:dev_stack/core/services/ssl_service.dart';

void main() {
  group('mkcert asset basename', () {
    test('windows keeps the legacy unversioned exe', () {
      expect(SslService.mkcertAssetBasename(isLinux: false),
          equals('mkcert.exe'));
    });

    test('linux selects per-arch versioned binary', () {
      expect(
        SslService.mkcertAssetBasename(
            isLinux: true, dartVersion: '3.10.4 (stable) ... on "linux_x64"'),
        equals('mkcert-v1.4.4-linux-amd64'),
      );
      expect(
        SslService.mkcertAssetBasename(
            isLinux: true, dartVersion: '3.10.4 (stable) ... on "linux_arm64"'),
        equals('mkcert-v1.4.4-linux-arm64'),
      );
      expect(
        SslService.mkcertAssetBasename(
            isLinux: true, dartVersion: '3.10.4 (stable) ... on "linux_arm"'),
        equals('mkcert-v1.4.4-linux-arm'),
      );
    });

    test('unknown linux arch defaults to amd64', () {
      expect(SslService.mkcertAssetBasename(isLinux: true, dartVersion: ''),
          equals('mkcert-v1.4.4-linux-amd64'));
    });
  });

  group('buildElevatedMkcertArgs', () {
    test('linux wraps execution in sh forwarding CAROOT and chown', () {
      final cmd = SslService.buildElevatedMkcertArgs(
        mkcertPath: '/home/u/.ponta/bin/mkcert',
        carootPath: '/home/u/.local/share/mkcert',
        action: '-install',
        username: 'testuser',
        isLinux: true,
      );

      expect(cmd.executable, equals('sh'));
      expect(cmd.arguments[0], equals('-c'));
      expect(cmd.arguments[1], contains('export CAROOT="\$1"'));
      expect(cmd.arguments[1], contains('chown -R "\$4" "\$1"'));
      expect(cmd.arguments[2], equals('sh'));
      expect(cmd.arguments[3], equals('/home/u/.local/share/mkcert'));
      expect(cmd.arguments[4], equals('/home/u/.ponta/bin/mkcert'));
      expect(cmd.arguments[5], equals('-install'));
      expect(cmd.arguments[6], equals('testuser'));
    });

    test('linux supports uninstall action with CAROOT forwarding', () {
      final cmd = SslService.buildElevatedMkcertArgs(
        mkcertPath: '/usr/bin/mkcert',
        carootPath: '/home/dev/.local/share/mkcert',
        action: '-uninstall',
        username: 'dev',
        isLinux: true,
      );

      expect(cmd.executable, equals('sh'));
      expect(cmd.arguments[5], equals('-uninstall'));
      expect(cmd.arguments[3], equals('/home/dev/.local/share/mkcert'));
    });

    test('windows executes mkcert binary directly with action argument', () {
      final cmd = SslService.buildElevatedMkcertArgs(
        mkcertPath: r'C:\ponta\bin\mkcert.exe',
        carootPath: r'C:\Users\u\AppData\Local\mkcert',
        action: '-install',
        username: 'u',
        isLinux: false,
      );

      expect(cmd.executable, equals(r'C:\ponta\bin\mkcert.exe'));
      expect(cmd.arguments, equals(['-install']));
    });
  });
}
