import '../linux_php_extension_driver.dart';

/// Arch Linux and derivatives (Manjaro, EndeavourOS, ...).
///
/// Extensions are discovered via `pacman -Ss` and `pacman -Fl`.
/// Output paths from `pacman -Fl` lack a leading slash (`usr/lib/php/modules/gd.so`),
/// so [parseFileListLine] normalises them by prepending `/`.
///
/// Bundled packages (`php-gd`, `php-sqlite`, etc.) ship only `.so` files with
/// no ini files in `/etc/php/conf.d/`. Enabling and disabling uses
/// [PhpIniStrategy.ownIniFile]: the manager writes `<scanDir>/99-ponta-<ext>.ini`
/// when enabling, and comments out the loader line in every parsed ini when
/// disabling. Nothing is ever deleted — `rm` is not on the validator's allowlist.
class ArchPhpExtensionDriver extends LinuxPhpExtensionDriver {
  @override
  String get family => 'arch';

  @override
  PhpIniStrategy get iniStrategy => PhpIniStrategy.ownIniFile;

  @override
  List<String> packageListCommands(String phpVersion) => ['pacman -Ss php-'];

  @override
  List<PackageCandidate> parsePackageList(String stdout, String phpVersion) {
    final candidates = <PackageCandidate>[];
    final lines = stdout.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.isEmpty || line.startsWith(' ')) continue;
      final slash = line.indexOf('/');
      if (slash < 0) continue;
      final name = line.substring(slash + 1).split(' ').first;
      if (!LinuxPhpExtensionDriver.isSafeName(name)) continue;

      var description = '';
      if (i + 1 < lines.length && lines[i + 1].startsWith(' ')) {
        description = lines[i + 1].trim();
      }
      candidates.add(PackageCandidate(name: name, description: description));
    }
    return candidates;
  }

  @override
  List<String> fileListCommands(
    String phpVersion,
    List<PackageCandidate> packages,
  ) {
    final names = packages
        .map((p) => p.name)
        .where(LinuxPhpExtensionDriver.isSafeName)
        .toList();
    if (names.isEmpty) return ['pacman -Fl'];
    return ['pacman -Fl ${names.join(' ')}'];
  }

  @override
  ({String? package, String path})? parseFileListLine(String line) {
    final sep = line.indexOf(' ');
    if (sep <= 0) return null;
    var path = line.substring(sep + 1).trim();
    if (!path.startsWith('/')) path = '/$path';
    return (package: line.substring(0, sep).trim(), path: path);
  }

  @override
  List<String> installCommands(PackageCandidate pkg, String phpVersion) => [
    'pacman -S --noconfirm ${pkg.name}',
  ];

  @override
  List<String> enableCommands(String phpVersion, String extName) => const [];

  @override
  List<String> disableCommands(String phpVersion, String extName) => const [];
}
