import 'package:path/path.dart' as p;

import 'php_extension_drivers/arch_php_extension_driver.dart';
import 'php_extension_drivers/debian_php_extension_driver.dart';
import 'php_extension_drivers/rhel_php_extension_driver.dart';

/// A package the distro can install, together with the extensions it provides.
class PackageCandidate {
  final String name;
  final String description;
  final List<String> extensionNames;

  const PackageCandidate({
    required this.name,
    this.description = '',
    this.extensionNames = const [],
  });

  /// An extension with no package behind it: it is compiled into the PHP
  /// binary itself, so there is nothing to install. `opcache` is the case that
  /// matters in practice — it ships no `.so` on Debian, RHEL or Arch for 8.5.
  const PackageCandidate.synthetic(this.extensionNames)
    : name = '',
      description = '';

  bool get hasPackage => name.isNotEmpty;
}

/// How a family turns an extension on and off.
enum PhpIniStrategy {
  /// Debian/Ubuntu: `phpenmod` / `phpdismod` manage the `conf.d` symlinks, so we
  /// never write an ini file ourselves.
  externalTool,

  /// RHEL/Fedora and Arch: we own `<scanDir>/99-ponta-<ext>.ini`. Disabling
  /// also has to neutralise any ini the distro shipped for the same extension.
  ownIniFile,
}

/// Supplies everything distro-specific about managing PHP extensions.
///
/// The package-to-extension mapping is **not** a table: it is read from each
/// package's own file list and filtered by the binary's `extension_dir`
/// (see the spec, §2.7). That is why [parseFileList] lives here and is shared
/// by every family.
abstract class LinuxPhpExtensionDriver {
  String get family;

  PhpIniStrategy get iniStrategy;

  List<String> packageListCommands(String phpVersion);

  List<PackageCandidate> parsePackageList(String stdout, String phpVersion);

  List<String> fileListCommands(String phpVersion, List<PackageCandidate> packages);

  /// Splits one file-list line into its package and absolute path, or null when
  /// the line carries no file entry.
  ({String package, String path})? parseFileListLine(String line);

  /// Keeps only `.so` files whose immediate parent directory is [extensionDir].
  ///
  /// This single rule replaces the prefix-stripping heuristic and its exception
  /// table. Junk is excluded by construction: Remi's `php-embedded` ships
  /// `/usr/lib64/libphp.so`, `uwsgi-plugin-php` ships
  /// `/usr/lib64/uwsgi/php_plugin.so`, and Arch's `php-apache` ships
  /// `/usr/lib/httpd/modules/libphp.so` — none of them under an
  /// `extension_dir`.
  Map<String, List<String>> parseFileList(String stdout, String extensionDir) {
    final byPackage = <String, List<String>>{};
    for (final raw in stdout.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final entry = parseFileListLine(line);
      if (entry == null) continue;
      if (!LinuxPhpExtensionDriver.isSafeName(entry.package)) continue;

      final path = entry.path;
      if (!path.endsWith('.so')) continue;
      // Compare directories, not the file name: the extension name is the file
      // name, and the package name is irrelevant.
      if (p.posix.dirname(path) != extensionDir) continue;

      final extName = p.posix.basenameWithoutExtension(path);
      if (!LinuxPhpExtensionDriver.isSafeName(extName)) continue;
      byPackage.putIfAbsent(entry.package, () => <String>[]).add(extName);
    }
    for (final names in byPackage.values) {
      names.sort();
    }
    return byPackage;
  }

  /// Attaches the extension names from [filesByPackage] to each package,
  /// dropping the packages that ship none.
  List<PackageCandidate> combine(
    List<PackageCandidate> packages,
    Map<String, List<String>> filesByPackage,
  ) {
    final result = <PackageCandidate>[];
    for (final pkg in packages) {
      final names = filesByPackage[pkg.name];
      if (names == null || names.isEmpty) continue;
      result.add(
        PackageCandidate(
          name: pkg.name,
          description: pkg.description,
          extensionNames: names,
        ),
      );
    }
    return result;
  }

  List<String> installCommands(PackageCandidate pkg, String phpVersion);

  List<String> enableCommands(String phpVersion, String extName);

  List<String> disableCommands(String phpVersion, String extName);

  String iniFileNameFor(String extName) => '99-ponta-$extName.ini';

  /// `opcache` and `xdebug` need `zend_extension=` rather than `extension=`.
  bool isZendExtension(String extName) =>
      extName == 'opcache' || extName == 'xdebug';

  /// The ERE body (no `s,`/delimiter, no replacement) that comments out the
  /// line loading [extName] in an ini file. Shared by RHEL and Arch; Debian
  /// uses `phpdismod` and never builds a pattern.
  ///
  /// Two forms exist and both are covered:
  /// - a loader line — `extension=redis.so`, `zend_extension="redis.so"`,
  ///   `extension=/usr/lib64/php/modules/redis.so`, `extension=redis`;
  /// - `opcache`'s directive form, `opcache.enable=1`, which is an assignment
  ///   rather than a loader line (spec §2.5) and needs its own alternative.
  ///
  /// The name is anchored (`(.*/)?NAME(\.so)?"?\s*$`) so `pdo` cannot
  /// match `pdo_mysql`. ERE, not BRE: busybox `sed` has no `\?`.
  ///
  /// `\s`, not `[[:space:]]`: Dart's `RegExp` is ECMAScript, where the POSIX
  /// class is not a class at all — it is the literal set `{[, :, s, p, a, c, e}`,
  /// so `^[[:space:]]*$` would match `":"` and *reject* a line of spaces.
  /// `\s` works in both runtimes (Dart `RegExp` and GNU/busybox `sed`).
  ///
  /// Every `\s` sits in a **raw** string: in a non-raw literal `'\s'` is the
  /// escape `\s`, which Dart silently reduces to `s`, turning the anchor into
  /// `...s*$` — a pattern that matches almost nothing. The name is spliced in
  /// by concatenation because a raw string also disables `$name`
  /// interpolation.
  String disableIniPattern(String extName) {
    final name = RegExp.escape(extName);
    if (extName == 'opcache') {
      return r'^\s*opcache\.enable\s*=.*$';
    }
    return r'^\s*(zend_)?extension\s*=\s*"?(.*/)?' +
        name +
        r'(\.so)?"?\s*$';
  }

  /// Splits a discovery command into argv, stripping the single quotes the
  /// commands carry.
  ///
  /// The commands are written quoted (`apt-file list -x '^php8.5-'`) because
  /// that is how a human would paste them into a shell. But discovery runs
  /// through `Process.run` — direct argv, no shell — so the quotes would reach
  /// `apt-file`/`dnf` as literal characters and the pattern would match
  /// nothing. This is why the tests stub `apt-file list -x ^php8.5-` with no
  /// quotes.
  static List<String> splitCommand(String command) {
    final parts = <String>[];
    final buffer = StringBuffer();
    var inSingle = false;
    for (var i = 0; i < command.length; i++) {
      final ch = command[i];
      if (ch == "'") {
        inSingle = !inSingle;
        continue;
      }
      if ((ch == ' ' || ch == '\t') && !inSingle) {
        if (buffer.isNotEmpty) {
          parts.add(buffer.toString());
          buffer.clear();
        }
        continue;
      }
      buffer.write(ch);
    }
    if (buffer.isNotEmpty) parts.add(buffer.toString());
    return parts;
  }

  /// Package and extension names come from package-manager output, which is a
  /// semi-trusted source. Anything that is not a plain lower-case name is
  /// dropped rather than sanitised, so it can never reach a shell.
  static final RegExp _safeName = RegExp(r'^[a-z0-9][a-z0-9._+-]*$');

  static bool isSafeName(String name) => _safeName.hasMatch(name);
}

/// Returns the driver for [family], or null when the family is unsupported.
///
/// `unknown` deliberately yields null: the extension manager must show an
/// explicit "unsupported distribution" message rather than guess a package
/// manager.
LinuxPhpExtensionDriver? driverForFamily(String family) {
  switch (family) {
    case 'ubuntu':
    case 'debian':
      return DebianPhpExtensionDriver();
    case 'centos':
    case 'fedora':
      return RhelPhpExtensionDriver();
    case 'arch':
      return ArchPhpExtensionDriver();
    default:
      return null;
  }
}
