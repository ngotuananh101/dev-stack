import '../linux_php_extension_driver.dart';

/// Debian and Ubuntu.
///
/// Extensions are enabled through `mods-available/*.ini` plus per-SAPI
/// `conf.d/` symlinks, managed by `phpenmod` / `phpdismod`. Only modules
/// already present on disk are configured; package installation is unsupported.
///
/// File lists come from `apt-file`, which needs a one-time `apt-file update`
/// before it can answer. `apt-file list -x` matches the pattern against package
/// names and prints `package: /path`.
class DebianPhpExtensionDriver extends LinuxPhpExtensionDriver {
  @override
  String get family => 'debian';

  @override
  PhpIniStrategy get iniStrategy => PhpIniStrategy.externalTool;

  @override
  List<String> packageListCommands(String phpVersion) => [
    'apt-cache search --names-only php$phpVersion-',
  ];

  @override
  List<PackageCandidate> parsePackageList(String stdout, String phpVersion) {
    final candidates = <PackageCandidate>[];
    for (final raw in stdout.split('\n')) {
      final line = raw.trim();
      final sep = line.indexOf(' - ');
      if (sep <= 0) continue;
      final name = line.substring(0, sep).trim();
      if (!LinuxPhpExtensionDriver.isSafeName(name)) continue;
      candidates.add(
        PackageCandidate(
          name: name,
          description: line.substring(sep + 3).trim(),
        ),
      );
    }
    return candidates;
  }

  @override
  List<String> fileListCommands(
    String phpVersion,
    List<PackageCandidate> packages,
  ) {
    // Matches the spec §2.8 form exactly: the version prefix, then a literal
    // '-'. The trailing dot of an earlier draft (`^php8\.5\.`) matched
    // `php8.5-...` by accident while reading as if it targeted `php8.5.`
    // packages; the dash is what the Debian archive actually uses.
    return ["apt-file list -x '^php$phpVersion-'"];
  }

  @override
  ({String? package, String path})? parseFileListLine(String line) {
    final sep = line.indexOf(': ');
    if (sep <= 0) return null;
    return (package: line.substring(0, sep), path: line.substring(sep + 2));
  }

  @override
  List<String> enableCommands(String phpVersion, String extName) => [
    'phpenmod -v $phpVersion -s fpm $extName',
  ];

  @override
  List<String> disableCommands(String phpVersion, String extName) => [
    'phpdismod -v $phpVersion -s fpm $extName',
  ];
}
