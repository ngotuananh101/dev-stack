import 'dart:io';

/// The effective PHP-FPM configuration, as reported by the binary itself.
///
/// Every field is nullable because phpinfo prints `(none)` for unset values,
/// and because a binary that fails to run yields no information at all.
class PhpFpmInfo {
  final String? scanDir;
  final String? extensionDir;
  final String? iniPath;
  final List<String> scannedIniFiles;

  const PhpFpmInfo({
    this.scanDir,
    this.extensionDir,
    this.iniPath,
    this.scannedIniFiles = const [],
  });

  static const PhpFpmInfo empty = PhpFpmInfo();
}

/// Reads a php-fpm binary's own view of its configuration.
///
/// `php-fpm -i` runs `php_module_startup()` (which loads php.ini and the
/// compile-time scan directory) and prints phpinfo as plain text, then exits
/// before `fpm_init()`. It therefore needs no `-y` pool config, does not
/// daemonize, does not bind a socket, and does not refuse to run as root.
/// `php-fpm -m` lists the compiled-in and loaded modules the same way.
///
/// The scan directory and `extension_dir` are properties of the binary — each
/// SAPI is built with its own `--with-config-file-scan-dir` — so reading them
/// here is always correct and no per-distro path needs to be hardcoded.
class LinuxPhpIntrospector {
  LinuxPhpIntrospector({
    Future<ProcessResult> Function(String, List<String>)? runProcess,
  }) : _runProcess = runProcess ?? Process.run;

  final Future<ProcessResult> Function(String, List<String>) _runProcess;

  Future<PhpFpmInfo> readInfo(String binaryPath) async {
    final stdout = await _run(binaryPath, ['-i']);
    if (stdout == null) return PhpFpmInfo.empty;

    final values = <String, String>{};
    String? currentLabel;
    for (final line in stdout.split('\n')) {
      if (line.trim().isEmpty) {
        // A blank line ends the directive it belonged to. This matters
        // because `-i` output is sectioned (`Core`, `date`, …) and a section
        // header carries no ` => `, so without this reset it would be
        // appended to whichever directive happened to precede it.
        currentLabel = null;
        continue;
      }
      final idx = line.indexOf(' => ');
      if (idx > 0) {
        currentLabel = line.substring(0, idx).trim();
        values.putIfAbsent(currentLabel, () => line.substring(idx + 4).trim());
        continue;
      }
      // A continuation of a wrapped value. `main/php_ini.c` joins the scanned
      // ini list with `",\n"`, so every path after the first lands on its own
      // line with no ` => ` to anchor it. Appending it to the label we are
      // inside of is what makes `scannedIniFiles` complete instead of a
      // one-element list.
      final label = currentLabel;
      if (label != null) {
        final continuation = line.trim();
        values.update(label, (v) => '$v\n$continuation');
      }
    }

    return PhpFpmInfo(
      scanDir: _orNull(values['Scan this dir for additional .ini files']),
      // `extension_dir` is a three-column row — `extension_dir => <local> =>
      // <master>` — unlike the two-column rows around it, so the value here
      // is still `<local> => <master>`. Take the first column.
      extensionDir: _orNull(values['extension_dir']?.split(' => ').first),
      iniPath: _orNull(values['Loaded Configuration File']),
      scannedIniFiles: _splitIniList(values['Additional .ini files parsed']),
    );
  }

  Future<Set<String>> readModules(String binaryPath) async {
    final stdout = await _run(binaryPath, ['-m']);
    if (stdout == null) return <String>{};

    final modules = <String>{};
    for (final raw in stdout.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('[')) continue;
      modules.add(line);
    }
    return modules;
  }

  /// Runs the binary and returns stdout, or null when it cannot be used.
  Future<String?> _run(String binaryPath, List<String> args) async {
    try {
      final result = await _runProcess(binaryPath, args);
      if (result.exitCode != 0) return null;
      return result.stdout.toString();
    } catch (_) {
      return null;
    }
  }

  static String? _orNull(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == '(none)') return null;
    return trimmed;
  }

  /// `main/php_ini.c` joins scanned ini paths with `",\n"` and terminates the
  /// list with `"\n"` — not spaces, which a naive split would get wrong.
  static List<String> _splitIniList(String? value) {
    if (value == null) return const [];
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == '(none)') return const [];
    return trimmed
        .split(',')
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList();
  }
}
