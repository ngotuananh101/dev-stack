import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/services/background_process.dart';
import '../domain/app_model.dart';
import '../domain/php_extension.dart';
import 'app_installer_service.dart';
import 'linux_php_extension_driver.dart';
import 'linux_php_introspector.dart';
import 'package_command_validator.dart';

/// Thrown when package discovery cannot run honestly (spec §2.8): the
/// bootstrap tool (`apt-file`, or the `pacman` files database) is missing.
/// Callers show an explicit message rather than a guessed extension list.
class LinuxPhpDiscoveryUnavailable implements Exception {
  final String message;
  const LinuxPhpDiscoveryUnavailable(this.message);

  @override
  String toString() => 'LinuxPhpDiscoveryUnavailable: $message';
}

typedef _ElevatedRunner =
    Future<ProcessResult> Function({
      required List<String> commands,
      required void Function(String) logInfo,
      required void Function(String) logError,
    });

/// Orchestrates Linux PHP extension discovery and the single-switch toggle
/// flow (spec §3, §5). Every external interaction is injectable so the whole
/// flow runs on Windows CI with string fixtures.
class LinuxPhpExtensionManager {
  final LinuxPhpIntrospector _introspector;
  final LinuxPhpExtensionDriver _driver;
  final Future<ProcessResult> Function(String, List<String>) _runProcess;
  final _ElevatedRunner _runElevated;
  final Future<void> Function(int pid) _reloader;
  final bool Function(String path) _fileExists;

  LinuxPhpExtensionManager({
    required LinuxPhpIntrospector introspector,
    required LinuxPhpExtensionDriver driver,
    required Future<ProcessResult> Function(String, List<String>) runProcess,
    _ElevatedRunner? runElevated,
    Future<void> Function(int pid)? reloader,
    bool Function(String path)? fileExists,
  }) : _introspector = introspector,
       _driver = driver,
       _runProcess = runProcess,
       _runElevated = runElevated ?? _buildDefaultElevatedRunner(runProcess),
       _reloader =
           reloader ??
           ((pid) async {
             final args = BackgroundProcess.buildLinuxReloadArgs(pid);
             final result = await runProcess(args.executable, args.arguments);
             if (result.exitCode != 0) {
               throw ProcessException(
                 args.executable,
                 args.arguments,
                 result.stderr.toString(),
                 result.exitCode,
               );
             }
           }),
       _fileExists = fileExists ?? ((path) => File(path).existsSync());

  static _ElevatedRunner _buildDefaultElevatedRunner(
    Future<ProcessResult> Function(String, List<String>) runProcess,
  ) {
    return ({
      required List<String> commands,
      required void Function(String) logInfo,
      required void Function(String) logError,
    }) => AppInstallerService.executePackageManagerCommands(
      commands: commands,
      logInfo: logInfo,
      logError: logError,
      runProcess: runProcess,
    );
  }

  factory LinuxPhpExtensionManager.forApp({
    required AppModel app,
    required LinuxPhpExtensionDriver driver,
    Future<ProcessResult> Function(String, List<String>)? runProcess,
  }) {
    return LinuxPhpExtensionManager(
      introspector: LinuxPhpIntrospector(runProcess: runProcess),
      driver: driver,
      runProcess: runProcess ?? Process.run,
    );
  }

  /// The full extension list for the Extensions tab (spec §3.1).
  Future<List<PhpExtension>> listExtensions({
    required String binaryPath,
    required String phpVersion,
  }) async {
    final info = await _introspector.readInfo(binaryPath);
    final enabled = await _introspector.readModules(binaryPath);
    final extensionDir = info.extensionDir ?? '';

    final packages = await _listPackages(phpVersion);
    final filesByPackage = await _listFiles(phpVersion, packages, extensionDir);
    final combined = _driver.combine(packages, filesByPackage);

    final byExtension = <String, PackageCandidate>{};
    for (final pkg in combined) {
      for (final extName in pkg.extensionNames) {
        byExtension.putIfAbsent(extName, () => pkg);
      }
    }
    // Statically compiled modules (opcache) arrive from the module side.
    for (final extName in enabled) {
      if (!LinuxPhpExtensionDriver.isSafeName(extName)) continue;
      byExtension.putIfAbsent(
        extName,
        () => PackageCandidate.synthetic([extName]),
      );
    }

    final result = <PhpExtension>[];
    for (final entry in byExtension.entries) {
      final extName = entry.key;
      final pkg = entry.value;
      final isEnabled = enabled.contains(extName);
      // A synthetic entry has no .so by construction; it is manageable, so it
      // must not render "Not installed". Every other entry — including one
      // whose owner package is not yet named (dnf4) — is judged by its .so.
      final isInstalled =
          pkg.isSynthetic || _fileExists('$extensionDir/$extName.so');
      result.add(
        PhpExtension(
          name: extName,
          fileName: '$extName.so',
          isEnabled: isEnabled,
          isFoundInIni: isEnabled || isInstalled,
          isZend: _driver.isZendExtension(extName),
          isInstalled: isInstalled,
          packageName: pkg.hasPackage ? pkg.name : null,
          description: pkg.hasPackage && pkg.description.isNotEmpty
              ? pkg.description
              : null,
        ),
      );
    }
    result.sort((a, b) => a.name.compareTo(b.name));
    return result;
  }

  Future<List<PackageCandidate>> _listPackages(String phpVersion) async {
    final out = <PackageCandidate>[];
    for (final cmd in _driver.packageListCommands(phpVersion)) {
      final stdout = await _runDiscovery(cmd);
      if (stdout == null) continue;
      out.addAll(_driver.parsePackageList(stdout, phpVersion));
    }
    return out;
  }

  /// Reads the package→extension map, trying the driver's file-list commands in
  /// order and keeping the first that parses to something. The order matters on
  /// the dnf family: dnf5's attributed `--qf '%{name} %{files}'` form prints a
  /// block per package, while dnf4 rejects it with exit 2 or prints the literal
  /// `%{files}` — so the driver offers both and the first usable one wins.
  Future<Map<String, List<String>>> _listFiles(
    String phpVersion,
    List<PackageCandidate> packages,
    String extensionDir,
  ) async {
    for (final cmd in _driver.fileListCommands(phpVersion, packages)) {
      final stdout = await _runDiscovery(cmd);
      if (stdout == null) continue;
      final parsed = _driver.parseFileList(stdout, extensionDir);
      if (parsed.isEmpty) continue;
      for (final names in parsed.values) {
        names.sort();
      }
      return parsed;
    }
    return <String, List<String>>{};
  }

  /// Runs one discovery command. Returns null when the command failed but the
  /// list can still be partial; throws [LinuxPhpDiscoveryUnavailable] when the
  /// failure means the tool itself is missing.
  ///
  /// A missing tool does **not** arrive as exit 127 here: discovery goes
  /// through `Process.run` (direct argv, no shell), and Dart throws a
  /// [ProcessException] when the executable cannot be found — it never spawns
  /// a shell that could report 127. So the `ProcessException` arm is the one
  /// that matters for `apt-file` / `pacman` not being installed. Getting this
  /// wrong is a silent failure: the exception would fall into the generic
  /// `catch` below, discovery would return null, and the user would see an
  /// empty extension list with no explanation — exactly what spec §2.8 forbids
  /// ("a wrong list is worse than an honest error"). The 127 check is kept as
  /// a belt-and-braces for a fake runner that models the shell convention.
  Future<String?> _runDiscovery(String command) async {
    final parts = _splitCommand(command);
    try {
      final result = await _runProcess(parts.first, parts.sublist(1));
      if (result.exitCode != 0) {
        if (result.exitCode == 127) {
          throw LinuxPhpDiscoveryUnavailable(
            'Discovery tool is missing for: $command',
          );
        }
        return null;
      }
      return result.stdout.toString();
    } on LinuxPhpDiscoveryUnavailable {
      rethrow;
    } on ProcessException catch (e) {
      throw LinuxPhpDiscoveryUnavailable(
        'Discovery tool could not be run for "$command": ${e.message}',
      );
    } catch (_) {
      return null;
    }
  }

  /// Installs (if needed) + enables, or disables, [extName], then reloads.
  Future<String> applyToggle({
    required String binaryPath,
    required String phpVersion,
    required String scanDir,
    required List<String> parsedIniFiles,
    required String extName,
    required bool enable,
    int? servicePid,
  }) async {
    if (!LinuxPhpExtensionDriver.isSafeName(extName)) {
      throw ArgumentError.value(extName, 'extName', 'Unsafe extension name');
    }
    if (enable) {
      return _enable(
        binaryPath: binaryPath,
        phpVersion: phpVersion,
        scanDir: scanDir,
        extName: extName,
        servicePid: servicePid,
      );
    }
    return _disable(
      binaryPath: binaryPath,
      phpVersion: phpVersion,
      scanDir: scanDir,
      parsedIniFiles: parsedIniFiles,
      extName: extName,
      servicePid: servicePid,
    );
  }

  Future<String> _enable({
    required String binaryPath,
    required String phpVersion,
    required String scanDir,
    required String extName,
    int? servicePid,
  }) async {
    // Resolve the owning package: the file list is the source of truth, so a
    // cheap re-discovery here handles toggles issued without a prior list.
    PackageCandidate? owner;
    String extensionDir = '';
    Object? discoveryError;
    try {
      final info = await _introspector.readInfo(binaryPath);
      extensionDir = info.extensionDir ?? '';
      final packages = await _listPackages(phpVersion);
      final files = await _listFiles(phpVersion, packages, extensionDir);
      final combined = _driver.combine(packages, files);
      for (final pkg in combined) {
        if (pkg.extensionNames.contains(extName)) {
          owner = pkg;
          break;
        }
      }
    } on LinuxPhpDiscoveryUnavailable catch (e) {
      // Remembered, not swallowed: if it turns out we needed the package (the
      // .so is not on disk) the caller gets the real reason — "install
      // apt-file" — instead of a misleading "did not load".
      discoveryError = e;
    } catch (_) {
      // Any other discovery failure is genuinely best-effort.
    }

    final isSynthetic = extName == 'opcache' && owner == null;
    final alreadyInstalled =
        isSynthetic || _fileExists('$extensionDir/$extName.so');

    if (owner == null && !alreadyInstalled && discoveryError != null) {
      throw discoveryError;
    }

    // A dnf4 file list names no package, so the owner arrives as a
    // `PackageCandidate.unknownOwner`. Name it now — only when the .so is
    // missing and an install would actually run — via `-f <path>`, which is the
    // one form that combines with `--qf` on both dnf4 and dnf5.
    String? ownerPackage =
        owner != null && owner.hasPackage ? owner.name : null;
    if (owner != null &&
        owner.ownerUnknown &&
        !alreadyInstalled &&
        extensionDir.isNotEmpty) {
      final resolved = await _resolveOwner(extensionDir, extName);
      if (resolved != null) ownerPackage = resolved;
    }

    final commands = <String>[];
    if (ownerPackage != null && !alreadyInstalled) {
      commands.addAll(
        _driver.installCommands(PackageCandidate(name: ownerPackage), phpVersion),
      );
    }
    if (_driver.iniStrategy == PhpIniStrategy.externalTool) {
      commands.addAll(_driver.enableCommands(phpVersion, extName));
    } else {
      commands.add(_enableIniCommand(scanDir, extName));
    }
    if (commands.isEmpty) {
      throw StateError('No enable step produced for $extName');
    }

    final rejection = PackageCommandValidator.validateAll(commands);
    if (rejection.isNotEmpty) {
      throw StateError('Refusing to run rejected commands: $rejection');
    }

    final logs = StringBuffer();
    await _runElevated(
      commands: commands,
      logInfo: (m) => logs.writeln(m),
      logError: (m) => logs.writeln('ERROR: $m'),
    );

    final reloadNote = await _reload(servicePid);
    await _verifyEnabled(binaryPath, extName, isSynthetic, logs.toString());
    return 'Extension $extName enabled.$reloadNote';
  }

  /// Names the package owning `<extensionDir>/<extName>.so`, or null when the
  /// family offers no owner query or the query yields no safe name. Best-effort:
  /// a failed query leaves the extension enableable, just without an install.
  Future<String?> _resolveOwner(String extensionDir, String extName) async {
    for (final cmd in _driver.resolveOwnerCommands(extensionDir, extName)) {
      final stdout = await _runDiscovery(cmd);
      if (stdout == null) continue;
      final owner = _driver.parseOwner(stdout);
      if (owner != null) return owner;
    }
    return null;
  }

  /// The command that turns an extension on for `ownIniFile` families.
  ///
  /// `opcache` is compiled into the FPM binary on every family (spec §2.5), so
  /// there is no `.so` to load: `zend_extension=opcache` would only emit
  /// `Failed loading Zend extension` warnings. The `opcache.enable` INI
  /// boolean is the real on/off switch (Remi's own `10-opcache.ini` ships
  /// `opcache.enable=1`).
  ///
  /// The line is delivered with `echo … | tee <file>` rather than a shell
  /// redirection: `>` is a forbidden substring in `PackageCommandValidator`,
  /// and both `echo` and `tee` are allowlisted. The target is left unquoted so
  /// the widened `_allowedTeeTargets` regex — which admits only
  /// `[\w.-]+\.ini` — is the thing that decides whether the write is legal.
  String _enableIniCommand(String scanDir, String extName) {
    final line = extName == 'opcache'
        ? 'opcache.enable=1'
        : '${_driver.isZendExtension(extName) ? 'zend_extension' : 'extension'}=$extName';
    final target = '$scanDir/${_driver.iniFileNameFor(extName)}';
    return "echo '$line' | tee $target";
  }

  Future<String> _disable({
    required String binaryPath,
    required String phpVersion,
    required String scanDir,
    required List<String> parsedIniFiles,
    required String extName,
    int? servicePid,
  }) async {
    final commands = <String>[];
    if (_driver.iniStrategy == PhpIniStrategy.externalTool) {
      commands.addAll(_driver.disableCommands(phpVersion, extName));
    } else {
      // Comment out the loader line in every ini the binary actually parsed.
      // Our own `99-ponta-<ext>.ini` is in that list (it is a file in scanDir,
      // so a freshly spawned `php-fpm -i` reports it), so this one command
      // covers both "our file" and "the distro's file" — no `rm` needed, which
      // matters because `rm` is not on the validator's allowlist.
      //
      // The pattern is anchored on the extension name so disabling `pdo` can
      // never knock out `pdo_mysql`. The replacement is the escape `\x3b`
      // (GNU sed) rather than a literal `;`, which the validator forbids
      // anywhere in a command. `,` is the sed delimiter because the pattern
      // itself contains `/` (the optional absolute-path group).
      //
      // The ini path is attacker-reachable: it is whatever `php-fpm -i` printed
      // for `Additional .ini files parsed`, and a poisoned ini in a
      // world-writable scan dir would land there. Two consequences make a bare
      // `startsWith('/')` gate insufficient, both verified by probe:
      //   1. `sed -i` would happily rewrite `/etc/shadow` or `/etc/sudoers`.
      //   2. the path is interpolated inside single quotes, so a filename
      //      containing `'` closes the quote early — `/etc/php.d/x.ini' -e
      //      's,.*,PWNED,w /tmp/p' -e '` turns into extra `sed` expressions
      //      and contains none of the validator's forbidden substrings.
      // The gate is therefore structural: the file must be a *plain child* of
      // the scan dir the binary itself reported, with a name that survives
      // `isSafeName` (which excludes `'`, `/`, spaces, and every other
      // metacharacter). Probe: this blocks 10/10 hostile paths and drops 0/6
      // legitimate ones (`/etc/php.d/…`, `/etc/php/conf.d/…`,
      // `/etc/php/8.5/fpm/conf.d/…`).
      final pattern = _driver.disableIniPattern(extName);
      for (final ini in parsedIniFiles) {
        if (p.posix.dirname(ini) != scanDir) continue;
        if (!LinuxPhpExtensionDriver.isSafeName(p.posix.basename(ini))) continue;
        commands.add(r"sed -E -i 's," + pattern + r',\x3b&,' + " '$ini'");
      }
    }
    if (commands.isEmpty) {
      throw StateError('No disable step produced for $extName');
    }

    final rejection = PackageCommandValidator.validateAll(commands);
    if (rejection.isNotEmpty) {
      throw StateError('Refusing to run rejected commands: $rejection');
    }

    await _runElevated(
      commands: commands,
      logInfo: (_) {},
      logError: (_) {},
    );

    final reloadNote = await _reload(servicePid);
    // No post-disable module check: for a static build, `opcache.enable=0`
    // keeps `opcache` listed in `php-fpm -m` while disabling acceleration.
    return 'Extension $extName disabled.$reloadNote';
  }

  /// Reloads the running FPM master, or reports a restart note on any failure
  /// (spec §5.3 and Review Focus item 4).
  Future<String> _reload(int? servicePid) async {
    if (servicePid == null) return '';
    try {
      await _reloader(servicePid);
      return '';
    } catch (_) {
      return ' PHP-FPM is not running — restart it to apply the change.';
    }
  }

  Future<void> _verifyEnabled(
    String binaryPath,
    String extName,
    bool isSynthetic,
    String logs,
  ) async {
    if (isSynthetic) return;
    final enabled = await _introspector.readModules(binaryPath);
    if (!enabled.contains(extName)) {
      throw Exception(
        'Extension $extName did not load after enabling. Output:\n$logs',
      );
    }
  }

  List<String> _splitCommand(String command) =>
      LinuxPhpExtensionDriver.splitCommand(command);
}
