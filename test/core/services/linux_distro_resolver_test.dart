import 'package:flutter_test/flutter_test.dart';
import 'package:dev_stack/core/services/linux_distro_resolver.dart';

void main() {
  group('LinuxDistroResolver - OS Release Parser', () {
    test('parses key-value pairs with quotes and unquotes them', () {
      const mockOsRelease = '''
NAME="Ubuntu"
VERSION="24.04 LTS (Noble Numbat)"
ID=ubuntu
ID_LIKE=debian
VERSION_CODENAME=noble
UBUNTU_CODENAME=noble
''';

      final map = LinuxDistroResolver.parseOsRelease(mockOsRelease);
      expect(map['NAME'], equals('Ubuntu'));
      expect(map['ID'], equals('ubuntu'));
      expect(map['VERSION_CODENAME'], equals('noble'));
      expect(map['UBUNTU_CODENAME'], equals('noble'));
    });

    test('ignores comments and empty lines', () {
      const mockOsRelease = '''
# Comment line
ID=debian
# Another comment

VERSION_ID="12"
''';

      final map = LinuxDistroResolver.parseOsRelease(mockOsRelease);
      expect(map.containsKey('#'), isFalse);
      expect(map['ID'], equals('debian'));
      expect(map['VERSION_ID'], equals('12'));
    });
  });

  group('LinuxDistroResolver - Codename and Target Detection', () {
    test('detects Ubuntu 24.04 Noble', () {
      const osRelease = '''
ID=ubuntu
VERSION_CODENAME=noble
''';
      expect(
        LinuxDistroResolver.resolveMongoDistro(
          osReleaseContent: osRelease,
          isLinux: true,
        ),
        equals('ubuntu2404'),
      );
    });

    test('detects Ubuntu 22.04 Jammy', () {
      const osRelease = '''
ID=ubuntu
VERSION_CODENAME=jammy
''';
      expect(
        LinuxDistroResolver.resolveMongoDistro(
          osReleaseContent: osRelease,
          isLinux: true,
        ),
        equals('ubuntu2204'),
      );
    });

    test('detects Ubuntu 20.04 Focal', () {
      const osRelease = '''
ID=ubuntu
VERSION_CODENAME=focal
''';
      expect(
        LinuxDistroResolver.resolveMongoDistro(
          osReleaseContent: osRelease,
          isLinux: true,
        ),
        equals('ubuntu2004'),
      );
    });

    test('detects Debian 12 Bookworm', () {
      const osRelease = '''
ID=debian
VERSION_ID="12"
VERSION_CODENAME=bookworm
''';
      expect(
        LinuxDistroResolver.resolveMongoDistro(
          osReleaseContent: osRelease,
          isLinux: true,
        ),
        equals('debian12'),
      );
    });

    test('falls back to safe defaults when unknown or empty', () {
      expect(
        LinuxDistroResolver.resolveMongoDistro(
          osReleaseContent: '',
          isLinux: true,
        ),
        equals('ubuntu2204'),
      );
    });
  });

  group('LinuxDistroResolver - URL Placeholder Resolution', () {
    test('resolves {mongo_distro} in URLs for Debian 12 host', () {
      const osRelease = 'ID=debian\nVERSION_CODENAME=bookworm';
      const template =
          'https://fastdl.mongodb.org/linux/mongodb-linux-x86_64-{mongo_distro}-8.0.4.tgz';

      final resolved = LinuxDistroResolver.resolveUrl(
        template,
        osReleaseContent: osRelease,
        isLinux: true,
      );

      expect(
        resolved,
        equals(
          'https://fastdl.mongodb.org/linux/mongodb-linux-x86_64-debian12-8.0.4.tgz',
        ),
      );
    });

    test('resolves {version_id} in URLs', () {
      const osRelease = 'ID=fedora\nVERSION_ID=41';
      const template = 'https://example.com/repo-{version_id}.rpm';

      final resolved = LinuxDistroResolver.resolveUrl(
        template,
        osReleaseContent: osRelease,
        isLinux: true,
      );

      expect(resolved, equals('https://example.com/repo-41.rpm'));
    });

    test('leaves standard static URLs without placeholders untouched', () {
      const url =
          'https://jirutka.github.io/nginx-binaries/bin/nginx-1.30.4-x86_64-linux';
      expect(LinuxDistroResolver.resolveUrl(url), equals(url));
    });
  });
}
