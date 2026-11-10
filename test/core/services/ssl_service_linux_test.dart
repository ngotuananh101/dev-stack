import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dev_stack/core/services/ssl_service.dart';

/// Whether the `openssl` CLI this suite drives is available. Production runs
/// the same binary, so a host without it cannot exercise the check at all.
final bool _hasOpenssl = () {
  try {
    return Process.runSync('openssl', ['version']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}();

void main() {
  group('mkcert asset basename', () {
    test('windows keeps the legacy unversioned exe', () {
      expect(
        SslService.mkcertAssetBasename(isLinux: false),
        equals('mkcert.exe'),
      );
    });

    test('linux selects per-arch versioned binary', () {
      expect(
        SslService.mkcertAssetBasename(
          isLinux: true,
          dartVersion: '3.10.4 (stable) ... on "linux_x64"',
        ),
        equals('mkcert-v1.4.4-linux-amd64'),
      );
      expect(
        SslService.mkcertAssetBasename(
          isLinux: true,
          dartVersion: '3.10.4 (stable) ... on "linux_arm64"',
        ),
        equals('mkcert-v1.4.4-linux-arm64'),
      );
      expect(
        SslService.mkcertAssetBasename(
          isLinux: true,
          dartVersion: '3.10.4 (stable) ... on "linux_arm"',
        ),
        equals('mkcert-v1.4.4-linux-arm'),
      );
    });

    test('unknown linux arch defaults to amd64', () {
      expect(
        SslService.mkcertAssetBasename(isLinux: true, dartVersion: ''),
        equals('mkcert-v1.4.4-linux-amd64'),
      );
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
      expect(cmd.arguments[1], startsWith('set -e;'));
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

  test('checks the standard Linux system trust-store bundles', () {
    expect(
      SslService.linuxTrustStoreBundles(),
      containsAll([
        '/etc/ssl/certs/ca-certificates.crt',
        '/etc/pki/tls/certs/ca-bundle.crt',
        '/etc/ssl/cert.pem',
      ]),
    );
  });

  group('certutil hint', () {
    test('Fedora and RHEL get their own package name', () {
      // `libnss3-tools` is the Debian/Ubuntu package; Fedora ships the same
      // certutil in `nss-tools`, so the hint has to follow the host.
      for (final id in ['fedora', 'rhel', 'centos', 'rocky', 'almalinux']) {
        final hint = SslService.certutilInstallHint(
          osReleaseId: id,
          osReleaseIdLike: 'rhel centos fedora',
        );
        expect(hint, contains('nss-tools'), reason: 'for $id');
        expect(hint, isNot(contains('libnss3-tools')), reason: 'for $id');
      }
    });

    test('Debian and Ubuntu keep libnss3-tools', () {
      final hint = SslService.certutilInstallHint(
        osReleaseId: 'ubuntu',
        osReleaseIdLike: 'debian',
      );
      expect(hint, contains('libnss3-tools'));
    });

    test('Arch and Alpine get their own package manager', () {
      expect(
        SslService.certutilInstallHint(osReleaseId: 'arch'),
        contains('nss'),
      );
      expect(
        SslService.certutilInstallHint(osReleaseId: 'alpine'),
        contains('nss-tools'),
      );
    });

    test('an unknown distro keeps a distro-neutral wording', () {
      final hint = SslService.certutilInstallHint(osReleaseId: 'exotic');
      expect(hint, isNot(contains('apt install')));
      expect(hint, isNot(contains('libnss3-tools')));
    });
  });

  group('nss package installation command', () {
    test('Fedora resolves to dnf and nss-tools', () {
      final cmd = SslService.nssToolsPackageManager(
        osReleaseId: 'fedora',
        osReleaseIdLike: 'rhel centos fedora',
      );
      expect(cmd, isNotNull);
      expect(cmd!.packageManager, equals('dnf'));
      expect(cmd.packageName, equals('nss-tools'));
    });

    test('Ubuntu resolves to apt-get and libnss3-tools', () {
      final cmd = SslService.nssToolsPackageManager(
        osReleaseId: 'ubuntu',
        osReleaseIdLike: 'debian',
      );
      expect(cmd?.packageManager, equals('apt-get'));
      expect(cmd?.packageName, equals('libnss3-tools'));
    });

    // apt-get, not apt: the app runs this non-interactively and apt's
    // "unstable CLI interface" warning is meant for humans.
    test('Debian family does not use the interactive apt front end', () {
      final cmd = SslService.nssToolsPackageManager(osReleaseId: 'debian');
      expect(cmd?.packageManager, isNot(equals('apt')));
    });

    test('Arch resolves to pacman', () {
      final cmd = SslService.nssToolsPackageManager(osReleaseId: 'arch');
      expect(cmd?.packageManager, equals('pacman'));
      expect(cmd?.packageName, equals('nss'));
    });

    test('Alpine resolves to apk', () {
      final cmd = SslService.nssToolsPackageManager(osReleaseId: 'alpine');
      expect(cmd?.packageManager, equals('apk'));
      expect(cmd?.packageName, equals('nss-tools'));
    });

    test('an unknown distro has no automatic command', () {
      expect(SslService.nssToolsPackageManager(osReleaseId: 'exotic'), isNull);
    });

    test('the refresh command never prompts', () {
      for (final manager in ['dnf', 'apt-get', 'pacman', 'apk', 'zypper']) {
        final args = SslService.packageRefreshArgs(manager);
        expect(args, isNotEmpty, reason: manager);
        // Each front end spells "do not ask me" differently, and apk's
        // `update` asks nothing at all.
        expect(
          args.any(
            (a) =>
                a == '-y' ||
                a == '--noconfirm' ||
                a == 'update' ||
                a == '--non-interactive',
          ),
          isTrue,
          reason:
              '$manager must not wait for a confirmation prompt (got $args)',
        );
      }
    });

    test('the install command never prompts', () {
      for (final manager in ['dnf', 'apt-get', 'pacman', 'apk', 'zypper']) {
        final args = SslService.packageInstallArgs(
          manager,
          'nss-tools',
          assumeYes: true,
        );
        expect(args, contains('nss-tools'), reason: manager);
        // Each front end spells "do not ask me" differently, and apk asks
        // nothing at all, so the check is "some flag stops the prompt".
        expect(
          args.any(
            (a) =>
                a == '-y' ||
                a == '--noconfirm' ||
                a == 'add' ||
                a == '--non-interactive',
          ),
          isTrue,
          reason:
              '$manager must not wait for a confirmation prompt (got $args)',
        );
      }
    });
  });

  // These drive the real `openssl verify` the app runs, against bundles built
  // here, so a regression in the arguments shows up as a wrong answer rather
  // than as a mismatch with a hand-written argv.
  group(
    'root CA trust detection',
    skip: _hasOpenssl ? false : 'openssl is not installed',
    () {
      late Directory tempDir;

      setUp(() async {
        tempDir = await Directory.systemTemp.createTemp('ponta_trust_test_');
      });

      tearDown(() async {
        if (tempDir.existsSync()) await tempDir.delete(recursive: true);
      });

      test('a CA present in the bundle is trusted', () async {
        final ca = await _generateCa(tempDir, 'installed');
        final bundle = _writeBundle(tempDir, 'bundle', [ca]);

        final trusted = await SslService.isRootCaTrusted(
          ca.path,
          bundles: [bundle.path],
        );

        expect(
          trusted,
          isTrue,
          reason:
              'the root CA is a self-signed trust anchor and is present in '
              'the bundle, which is what "installed" means',
        );
      });

      test(
        'a CA behind a same-subject decoy in the bundle is trusted',
        () async {
          // The production failure. mkcert's CA carries no Authority Key
          // Identifier, and every elevated `mkcert -install` without CAROOT
          // mints another CA under the same subject DN. OpenSSL then uses the
          // first same-subject certificate as the issuer, so a bundle holding a
          // stale CA before the live one made verification fail while the CA was
          // installed and the site's certificates verified fine.
          final stale = await _generateCa(tempDir, 'stale');
          final live = await _generateCa(tempDir, 'live');
          final bundle = _writeBundle(tempDir, 'bundle', [stale, live]);

          final trusted = await SslService.isRootCaTrusted(
            live.path,
            bundles: [bundle.path],
          );

          expect(trusted, isTrue);
        },
      );

      test('a CA absent from the bundle is not trusted', () async {
        final installed = await _generateCa(tempDir, 'installed');
        final other = await _generateCa(tempDir, 'other');
        final bundle = _writeBundle(tempDir, 'bundle', [installed]);

        final trusted = await SslService.isRootCaTrusted(
          other.path,
          bundles: [bundle.path],
        );

        expect(trusted, isFalse);
      });

      test('a same-subject CA with a different key is not trusted', () async {
        // Matching on the subject DN alone would call the uninstalled CA
        // trusted; the answer has to come from the key.
        final installed = await _generateCa(tempDir, 'installed');
        final impostor = await _generateCa(tempDir, 'impostor');
        final bundle = _writeBundle(tempDir, 'bundle', [installed]);

        expect(
          _subjectOf(impostor),
          equals(_subjectOf(installed)),
          reason: 'the two CAs must really share a subject for this to hold',
        );
        expect(
          await SslService.isRootCaTrusted(
            impostor.path,
            bundles: [bundle.path],
          ),
          isFalse,
        );
      });

      test('missing bundles are skipped', () async {
        final ca = await _generateCa(tempDir, 'installed');
        final bundle = _writeBundle(tempDir, 'bundle', [ca]);
        final missing = '${tempDir.path}/does-not-exist.pem';

        expect(
          await SslService.isRootCaTrusted(ca.path, bundles: [missing]),
          isFalse,
        );
        expect(
          await SslService.isRootCaTrusted(
            ca.path,
            bundles: [missing, bundle.path],
          ),
          isTrue,
        );
      });
    },
  );
}

String _subjectOf(File cert) {
  return Process.runSync('openssl', [
    'x509',
    '-in',
    cert.path,
    '-noout',
    '-subject',
  ]).stdout.toString();
}

/// Creates a self-signed CA and returns its PEM file.
///
/// The extensions mirror mkcert's own root CA: a critical `CA:TRUE` basic
/// constraint and key-cert-sign usage, and — unlike `openssl req -x509`'s
/// defaults — **no** Authority Key Identifier, which is what makes a
/// same-subject bundle ambiguous to OpenSSL.
Future<File> _generateCa(Directory dir, String name) async {
  final config = File('${dir.path}/ca.cnf');
  if (!config.existsSync()) {
    await config.writeAsString('''
[req]
distinguished_name = dn
prompt = no
x509_extensions = v3_ca
[dn]
CN = ponta test CA
[v3_ca]
basicConstraints = critical,CA:TRUE
keyUsage = critical,keyCertSign,cRLSign
''');
  }
  final cert = File('${dir.path}/$name.pem');
  final key = File('${dir.path}/$name.key');
  final result = await Process.run('openssl', [
    'req',
    '-x509',
    '-newkey',
    'rsa:2048',
    '-nodes',
    '-keyout',
    key.path,
    '-out',
    cert.path,
    '-days',
    '2',
    '-config',
    config.path,
  ]);
  if (result.exitCode != 0 || !cert.existsSync()) {
    fail('could not create a test CA: ${result.stderr}');
  }
  return cert;
}

/// Writes [certs] into one PEM bundle, in order, the way the system trust
/// store concatenates its anchors.
File _writeBundle(Directory dir, String name, List<File> certs) {
  final bundle = File('${dir.path}/$name.pem');
  final contents = StringBuffer();
  for (final cert in certs) {
    contents
      ..write(cert.readAsStringSync().trimRight())
      ..write('\n');
  }
  bundle.writeAsStringSync(contents.toString());
  return bundle;
}
