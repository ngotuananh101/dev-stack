import '../linux_php_extension_driver.dart';

/// RHEL, CentOS, Rocky, AlmaLinux and Fedora, including the Remi repository.
///
/// Extensions are discovered via `dnf repoquery`.
/// Extension names are resolved from package file lists (§2.7), which handles
/// arbitrary package naming without heuristics or exception tables (e.g.
/// `php-common` providing multiple extensions, `php-pecl-redis6` providing `redis`,
/// and non-extension libraries like `php-embedded` excluded by `extension_dir`).
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
    return [
      "dnf repoquery --qf '[%{=NAME}\\n]' 'php-*'$scl",
    ];
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
    return [
      "dnf repoquery -l --qf '[%{=NAME} %{FILENAMES}\\n]' 'php-*'$scl",
    ];
  }

  static String _sclPattern(String phpVersion) {
    final noDot = phpVersion.replaceAll('.', '');
    return noDot.isNotEmpty ? " 'php$noDot-php-*'" : '';
  }

  @override
  ({String package, String path})? parseFileListLine(String line) {
    final sep = line.indexOf(' ');
    if (sep <= 0) return null;
    var path = line.substring(sep + 1).trim();
    if (!path.startsWith('/')) path = '/$path';
    return (package: line.substring(0, sep).trim(), path: path);
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
