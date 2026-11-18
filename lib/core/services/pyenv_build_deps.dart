import 'dart:io';

import 'package:dev_stack/core/services/background_process.dart';
import 'package:flutter/foundation.dart';

/// The system libraries a Python built by pyenv needs, per Linux distro
/// family, and how to tell whether each one is already installed.
///
/// The package lists follow the pyenv wiki's "Suggested build environment".
/// Only packages with a confirmed probe are in the auto-install table: a
/// probe is a header path (`/usr/include/openssl/ssl.h`) or a binary
/// (`which:gcc`). A package whose probe cannot be confirmed is left out of
/// the auto-install list and named in [wikiInstallCommandFor] instead, so
/// the manual hint still shows the full wiki command.
///
/// The wiki has no Alpine section, so Alpine resolves to null here, and the
/// caller offers the manual command instead of guessing.
class PyenvBuildDeps {
  PyenvBuildDeps._();

  /// The package manager and the installable build dependencies for the
  /// distro family, or null for a family the app does not know how to
  /// install on.
  @visibleForTesting
  static ({String packageManager, List<({String package, String probe})> deps})?
  buildDepsFor({String? osReleaseId, String? osReleaseIdLike}) {
    final (id, idLike, family) = _family(osReleaseId, osReleaseIdLike);

    if (family.contains('debian') || family.contains('ubuntu')) {
      return (
        packageManager: 'apt-get',
        deps: const [
          (package: 'make', probe: 'which:make'),
          (package: 'build-essential', probe: 'which:gcc'),
          (package: 'libssl-dev', probe: '/usr/include/openssl/ssl.h'),
          (package: 'zlib1g-dev', probe: '/usr/include/zlib.h'),
          (package: 'libbz2-dev', probe: '/usr/include/bzlib.h'),
          (package: 'libreadline-dev', probe: '/usr/include/readline/readline.h'),
          (package: 'libsqlite3-dev', probe: '/usr/include/sqlite3.h'),
          (package: 'wget', probe: 'which:wget'),
          (package: 'curl', probe: 'which:curl'),
          (package: 'llvm', probe: 'which:llvm-config'),
          (package: 'libncursesw5-dev', probe: '/usr/include/ncurses.h'),
          (package: 'xz-utils', probe: 'which:xz'),
          (package: 'tk-dev', probe: '/usr/include/tk.h'),
          (package: 'libxml2-dev', probe: '/usr/include/libxml2/libxml/parser.h'),
          (package: 'libxmlsec1-dev', probe: '/usr/include/xmlsec1/xmlsec.h'),
          (package: 'libffi-dev', probe: '/usr/include/ffi.h'),
          (package: 'liblzma-dev', probe: '/usr/include/lzma.h'),
        ],
      );
    }
    if (family.contains('fedora') ||
        family.contains('rhel') ||
        family.contains('centos')) {
      return (
        packageManager: 'dnf',
        deps: const [
          (package: 'make', probe: 'which:make'),
          (package: 'gcc', probe: 'which:gcc'),
          (package: 'zlib-devel', probe: '/usr/include/zlib.h'),
          (package: 'bzip2', probe: 'which:bzip2'),
          (package: 'bzip2-devel', probe: '/usr/include/bzlib.h'),
          (package: 'readline-devel', probe: '/usr/include/readline/readline.h'),
          (package: 'sqlite', probe: 'which:sqlite3'),
          (package: 'sqlite-devel', probe: '/usr/include/sqlite3.h'),
          (package: 'openssl-devel', probe: '/usr/include/openssl/ssl.h'),
          (package: 'tk-devel', probe: '/usr/include/tk.h'),
          (package: 'libffi-devel', probe: '/usr/include/ffi.h'),
          (package: 'xz-devel', probe: '/usr/include/lzma.h'),
          (package: 'libuuid-devel', probe: '/usr/include/uuid/uuid.h'),
          (package: 'gdbm-devel', probe: '/usr/include/gdbm.h'),
        ],
      );
    }
    if (family.contains('suse')) {
      return (
        packageManager: 'zypper',
        deps: const [
          (package: 'gcc', probe: 'which:gcc'),
          (package: 'automake', probe: 'which:automake'),
          (package: 'bzip2', probe: 'which:bzip2'),
          (package: 'libbz2-devel', probe: '/usr/include/bzlib.h'),
          (package: 'xz', probe: 'which:xz'),
          (package: 'xz-devel', probe: '/usr/include/lzma.h'),
          (package: 'openssl-devel', probe: '/usr/include/openssl/ssl.h'),
          (package: 'ncurses-devel', probe: '/usr/include/ncurses.h'),
          (package: 'readline-devel', probe: '/usr/include/readline/readline.h'),
          (package: 'zlib-devel', probe: '/usr/include/zlib.h'),
          (package: 'tk-devel', probe: '/usr/include/tk.h'),
          (package: 'libffi-devel', probe: '/usr/include/ffi.h'),
          (package: 'sqlite3-devel', probe: '/usr/include/sqlite3.h'),
          (package: 'make', probe: 'which:make'),
        ],
      );
    }
    if (id == 'arch' || idLike.contains('arch')) {
      return (
        packageManager: 'pacman',
        deps: const [
          (package: 'base-devel', probe: 'which:gcc'),
          (package: 'openssl', probe: '/usr/include/openssl/ssl.h'),
          (package: 'zlib', probe: '/usr/include/zlib.h'),
          (package: 'xz', probe: '/usr/include/lzma.h'),
          (package: 'tk', probe: '/usr/include/tk.h'),
        ],
      );
    }
    return null;
  }

  /// The full pyenv-wiki install command for the distro family, as text the
  /// user can run by hand — including packages with no auto-install probe
  /// (e.g. `libnsl2-devel` on Fedora). Null for a family the wiki does not
  /// cover, so the caller falls back to the wiki URL.
  @visibleForTesting
  static String? wikiInstallCommandFor({
    String? osReleaseId,
    String? osReleaseIdLike,
  }) {
    final (id, idLike, family) = _family(osReleaseId, osReleaseIdLike);

    if (family.contains('debian') || family.contains('ubuntu')) {
      return 'sudo apt update; sudo apt install make build-essential '
          'libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev '
          'wget curl llvm libncursesw5-dev xz-utils tk-dev libxml2-dev '
          'libxmlsec1-dev libffi-dev liblzma-dev';
    }
    if (family.contains('fedora') ||
        family.contains('rhel') ||
        family.contains('centos')) {
      return 'sudo dnf install make gcc zlib-devel bzip2 bzip2-devel '
          'readline-devel sqlite sqlite-devel openssl-devel tk-devel '
          'libffi-devel xz-devel libuuid-devel gdbm-devel libnsl2-devel';
    }
    if (family.contains('suse')) {
      return 'sudo zypper install gcc automake bzip2 libbz2-devel xz '
          'xz-devel openssl-devel ncurses-devel readline-devel zlib-devel '
          'tk-devel libffi-devel sqlite3-devel make';
    }
    if (id == 'arch' || idLike.contains('arch')) {
      return 'sudo pacman -S --needed base-devel openssl zlib xz tk';
    }
    return null;
  }

  /// The package names in [deps] whose probe is absent, in table order.
  /// [probeExists] is injected by tests; the default checks header files
  /// with [File.existsSync] and `which:` probes with the `which` binary.
  static Future<List<String>> missingPackages(
    List<({String package, String probe})> deps, {
    Future<bool> Function(String probe)? probeExists,
  }) async {
    final exists = probeExists ?? _defaultProbeExists;
    final missing = <String>[];
    for (final dep in deps) {
      if (!await exists(dep.probe)) {
        missing.add(dep.package);
      }
    }
    return missing;
  }

  static (String, String, String) _family(
    String? osReleaseId,
    String? osReleaseIdLike,
  ) {
    final id = (osReleaseId ?? '').toLowerCase();
    final idLike = (osReleaseIdLike ?? '').toLowerCase();
    return (id, idLike, '$id $idLike');
  }

  static Future<bool> _defaultProbeExists(String probe) async {
    if (probe.startsWith('which:')) {
      final binary = probe.substring('which:'.length);
      try {
        final result = await BackgroundProcess.run('which', [binary]);
        return result.exitCode == 0;
      } on ProcessException {
        return false;
      }
    }
    return File(probe).existsSync();
  }
}
