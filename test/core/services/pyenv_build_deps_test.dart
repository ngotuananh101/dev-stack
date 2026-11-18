import 'package:dev_stack/core/services/pyenv_build_deps.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildDepsFor', () {
    test('fedora resolves the wiki dnf list', () {
      final deps = PyenvBuildDeps.buildDepsFor(
        osReleaseId: 'fedora',
        osReleaseIdLike: '',
      );
      expect(deps?.packageManager, equals('dnf'));
      expect(
        deps?.deps.map((d) => d.package),
        containsAll(['openssl-devel', 'readline-devel', 'gdbm-devel']),
      );
    });

    test('ubuntu resolves the wiki apt-get list', () {
      final deps = PyenvBuildDeps.buildDepsFor(
        osReleaseId: 'ubuntu',
        osReleaseIdLike: 'debian',
      );
      expect(deps?.packageManager, equals('apt-get'));
      expect(
        deps?.deps.map((d) => d.package),
        containsAll(['libssl-dev', 'libreadline-dev', 'tk-dev']),
      );
    });

    test('an unknown distro resolves to null', () {
      expect(
        PyenvBuildDeps.buildDepsFor(
          osReleaseId: 'gentoo',
          osReleaseIdLike: '',
        ),
        isNull,
      );
    });
  });

  group('wikiInstallCommandFor', () {
    test('the fedora hint names the full wiki command, including libnsl2-devel', () {
      final command = PyenvBuildDeps.wikiInstallCommandFor(
        osReleaseId: 'fedora',
        osReleaseIdLike: '',
      );
      expect(command, contains('dnf install'));
      expect(command, contains('libnsl2-devel'));
    });

    test('an unknown distro has no hint command', () {
      expect(
        PyenvBuildDeps.wikiInstallCommandFor(
          osReleaseId: 'gentoo',
          osReleaseIdLike: '',
        ),
        isNull,
      );
    });
  });

  group('missingPackages', () {
    test('missingPackages returns only the packages whose probe is absent', () async {
      final deps = [
        (package: 'openssl-devel', probe: '/usr/include/openssl/ssl.h'),
        (package: 'readline-devel', probe: '/usr/include/readline/readline.h'),
      ];
      final missing = await PyenvBuildDeps.missingPackages(
        deps,
        probeExists: (probe) async => probe.contains('openssl'),
      );
      expect(missing, equals(['readline-devel']));
    });
  });
}
