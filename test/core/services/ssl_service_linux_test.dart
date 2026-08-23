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
}
