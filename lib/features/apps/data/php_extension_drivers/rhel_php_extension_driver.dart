import '../linux_php_extension_driver.dart';

/// RHEL, CentOS, Rocky, AlmaLinux and Fedora, including the Remi repository.
///
/// Extensions are discovered via `dnf repoquery`.
/// Extension names are resolved from package file lists (§2.7), which handles
/// arbitrary package naming without heuristics or exception tables (e.g.
/// `php-common` providing multiple extensions, `php-pecl-redis6` providing `redis`,
/// and non-extension libraries like `php-embedded` excluded by `extension_dir`).
///
/// dnf4 and dnf5 need different discovery commands, and the driver emits both
/// so the manager can pick whichever the host runs (spec §2.8):
///
/// - **Names**: `dnf repoquery --qf '%{name}\n'` works on both. The old
///   `%{=NAME}` tag only exists in dnf4; on dnf5 it prints `[%{=NAME}` and the
///   package list comes back empty.
/// - **Files**: dnf5 accepts `--qf '%{name} %{files}\n'` and prints one block
///   per package (`pkg path`, then bare paths). dnf4 has no file tag for
///   `--qf` and forbids `-l` with `--qf`, so it can only print bare paths via
///   `-l` — leaving the owner unknown until enable time.
///
/// Enabling and disabling uses [PhpIniStrategy.ownIniFile]: the manager writes
/// `<scanDir>/99-ponta-<ext>.ini` when enabling, and comments out the loader
/// line in every parsed ini (ours *and* any distro-shipped one) when disabling.
/// Nothing is ever deleted — `rm` is not on the validator's allowlist.
class RhelPhpExtensionDriver extends LinuxPhpExtensionDriver {
  @override
  String get family => 'rhel';

  @override
  PhpIniStrategy get iniStrategy => PhpIniStrategy.ownIniFile;

  @override
  List<String> packageListCommands(String phpVersion) {
    final scl = _sclPattern(phpVersion);
    return ["dnf repoquery --qf '%{name}\\n' 'php-*'$scl"];
  }

  @override
  List<PackageCandidate> parsePackageList(String stdout, String phpVersion) {
    final candidates = <PackageCandidate>[];
    for (final raw in stdout.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (!LinuxPhpExtensionDriver.isSafeName(line)) continue;
      candidates.add(PackageCandidate(name: line, description: ''));
    }
    return candidates;
  }

  @override
  List<String> fileListCommands(
    String phpVersion,
    List<PackageCandidate> packages,
  ) {
    final scl = _sclPattern(phpVersion);
    // Ordered: the attributed dnf5 form first, the bare dnf4 form second. The
    // manager keeps the first command that exits 0 with output.
    return [
      "dnf repoquery --qf '%{name} %{files}\\n' 'php-*'$scl",
      "dnf repoquery -l 'php-*'$scl",
    ];
  }

  static String _sclPattern(String phpVersion) {
    final noDot = phpVersion.replaceAll('.', '');
    return noDot.isNotEmpty ? " 'php$noDot-php-*'" : '';
  }

  @override
  ({String? package, String path})? parseFileListLine(String line) {
    if (line.startsWith('/')) {
      // A bare path: either a dnf5 block continuation or a dnf4 `-l` line.
      return (package: null, path: line.trim());
    }
    final sep = line.indexOf(' ');
    if (sep <= 0) return null;
    var path = line.substring(sep + 1).trim();
    if (!path.startsWith('/')) path = '/$path';
    return (package: line.substring(0, sep).trim(), path: path);
  }

  @override
  List<String> resolveOwnerCommands(String extensionDir, String extName) {
    // `-f` is a filter, not a display mode, so it combines with `--qf` on both
    // dnf4 and dnf5 — the only form that prints the owning package for a known
    // path. The exact path is used because a `*` glob matches nothing here.
    return ["dnf repoquery --qf '%{name}\\n' -f '$extensionDir/$extName.so'"];
  }

  @override
  List<String> installCommands(PackageCandidate pkg, String phpVersion) => [
    'dnf install -y ${pkg.name}',
  ];

  @override
  List<String> enableCommands(String phpVersion, String extName) => const [];

  @override
  List<String> disableCommands(String phpVersion, String extName) => const [];
}
