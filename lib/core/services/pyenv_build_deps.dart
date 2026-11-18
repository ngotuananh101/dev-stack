import 'dart:io';

import 'package:dev_stack/core/config/app_config.dart';
import 'package:dev_stack/core/services/background_process.dart';
import 'package:dev_stack/core/services/linux_distro_resolver.dart';
import 'package:dev_stack/core/services/log_service.dart';
import 'package:dev_stack/core/services/pyenv_build_deps_declines.dart';
import 'package:dev_stack/core/services/ssl_service.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

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
  PyenvBuildDeps();

  static const _pyenvWikiUrl =
      'https://github.com/pyenv/pyenv/wiki#suggested-build-environment';

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

  /// The decision and the install behind [ensureBeforeInstall], with every
  /// outside dependency passed in so the flow can be tested without touching
  /// the real package manager or the user's decline file.
  ///
  /// Returns `true` when the Python install may proceed: nothing is missing,
  /// the user declined (they accept the build may fail), the install
  /// succeeded and the re-check is clean, the distro family is unknown, or
  /// pkexec is not available (in the last two cases the manual hint is
  /// logged instead). Returns `false` when the library install failed or
  /// the headers are still missing afterwards — the Python build must not
  /// run blind.
  @visibleForTesting
  static Future<bool> ensureBuildDeps({
    required Future<bool> Function(SslInstallPrompt prompt) askPermission,
    required PyenvBuildDepsDeclines declines,
    required List<String> missingPackages,
    required ({String packageManager, List<String> packageNames})? package,
    required Future<bool> Function() pkexecAvailable,
    required Future<ProcessResult> Function(
      String executable,
      List<String> arguments,
    )
    runElevated,
    void Function(SslInstallProgress progress)? onProgress,
    required Future<List<String>> Function() missingAfterwards,
  }) async {
    if (missingPackages.isEmpty) return true;

    final names = missingPackages.join(', ');
    final declineKey = (missingPackages.toList()..sort()).join(',');
    if (await declines.isDeclined(declineKey)) {
      AppLogger.info(
        'pyenv build libraries install was declined earlier; not asking again',
      );
      return true;
    }

    if (package == null) {
      // The app cannot install on this family, so tell the user what to run
      // instead of running a command that would fail.
      AppLogger.warning(
        'Python build libraries are missing ($names). Install them by hand: '
        '$_pyenvWikiUrl',
      );
      return true;
    }

    if (!await pkexecAvailable()) {
      // Without pkexec nothing can be installed elevated, so there is no
      // point showing a prompt for a command that cannot run: log the exact
      // command instead and let the Python install proceed.
      final manualArgs = SslService.packageInstallArgs(
        package.packageManager,
        package.packageNames,
      );
      AppLogger.warning(
        'pkexec is not available, so the build libraries cannot be '
        'installed automatically. Install them by hand: '
        '${SslService.describeCommand(package.packageManager, manualArgs)}',
      );
      return true;
    }

    final refreshArgs = SslService.packageRefreshArgs(package.packageManager);
    final installArgs = SslService.packageInstallArgs(
      package.packageManager,
      package.packageNames,
    );
    final prompt = SslInstallPrompt(
      title: 'Install Python build libraries?',
      message:
          'Python needs the "$names" packages to build. Without them the build fails or the new Python is missing features. This installs the packages system-wide.',
      command: SslService.describeCommand(package.packageManager, installArgs),
    );

    final allowed = await askPermission(prompt);
    if (!allowed) {
      await declines.decline(declineKey);
      AppLogger.info('User declined installing $names');
      return true;
    }

    // pkexec can take a while — it may be waiting on the desktop's
    // authentication dialog — so the caller is told the work started rather
    // than being left looking at a silent screen until the process exits.
    onProgress?.call(
      SslInstallProgress(
        status: InstallStatus.starting,
        message: 'Installing $names...',
      ),
    );

    if (refreshArgs.isNotEmpty) {
      final refresh = await runElevated(package.packageManager, refreshArgs);
      AppLogger.info(
        '${package.packageManager} refresh exit code: ${refresh.exitCode}',
      );
    }
    final install = await runElevated(package.packageManager, installArgs);
    AppLogger.info(
      '${package.packageManager} install $names exit code: '
      '${install.exitCode}',
    );

    if (install.exitCode != 0) {
      AppLogger.warning('Could not install $names: ${install.stderr}');
      onProgress?.call(
        SslInstallProgress(
          status: InstallStatus.failed,
          message: SslService.describeInstallFailure(
            names,
            install.exitCode,
            detail: install.stderr.toString().trim(),
          ),
        ),
      );
      return false;
    }

    // A package manager can exit 0 and still leave the headers missing, so
    // success is what the re-check says, not what the exit code says.
    final stillMissing = await missingAfterwards();
    if (stillMissing.isNotEmpty) {
      AppLogger.warning(
        '${package.packageManager} reported success installing $names but '
        'the headers are still missing: ${stillMissing.join(', ')}',
      );
      onProgress?.call(
        SslInstallProgress(
          status: InstallStatus.failed,
          message: '$names were installed, but the headers are still missing.',
        ),
      );
      return false;
    }

    onProgress?.call(
      SslInstallProgress(
        status: InstallStatus.succeeded,
        message: '$names installed.',
      ),
    );
    return true;
  }

  /// Makes sure the system libraries a pyenv Python build needs are
  /// installed before the build runs. Returns `true` when the Python install
  /// may proceed (see [ensureBuildDeps]); `false` aborts it.
  ///
  /// Linux only: pyenv-win does not build from source, so anywhere else this
  /// is a no-op that returns `true`.
  Future<bool> ensureBeforeInstall({
    required Future<bool> Function(SslInstallPrompt prompt) askPermission,
    void Function(SslInstallProgress progress)? onProgress,
  }) async {
    if (!Platform.isLinux) return true;

    final osRelease = await _readOsRelease();
    final id = osRelease['ID'];
    final idLike = osRelease['ID_LIKE'];
    final resolved = buildDepsFor(osReleaseId: id, osReleaseIdLike: idLike);
    if (resolved == null) {
      // No auto-install table for this family: offer the manual command.
      final manual =
          wikiInstallCommandFor(osReleaseId: id, osReleaseIdLike: idLike);
      AppLogger.warning(
        'Python build libraries may be missing. Install them by hand: '
        '${manual ?? _pyenvWikiUrl}',
      );
      return true;
    }

    final missing = await missingPackages(resolved.deps);
    return ensureBuildDeps(
      askPermission: askPermission,
      declines: PyenvBuildDepsDeclines(
        p.join(AppConfig.dataDir, 'pyenv', 'declines.json'),
      ),
      missingPackages: missing,
      package: (
        packageManager: resolved.packageManager,
        packageNames: missing,
      ),
      pkexecAvailable: () => _defaultProbeExists('which:pkexec'),
      runElevated: BackgroundProcess.runElevated,
      onProgress: onProgress,
      missingAfterwards: () => missingPackages(resolved.deps),
    );
  }

  static Future<Map<String, String>> _readOsRelease() async {
    try {
      final file = File('/etc/os-release');
      if (!await file.exists()) return <String, String>{};
      return LinuxDistroResolver.parseOsRelease(await file.readAsString());
    } catch (e) {
      AppLogger.warning('Could not read /etc/os-release: $e');
      return <String, String>{};
    }
  }
}
