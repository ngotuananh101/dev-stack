/// Security validator for shell commands sourced from app catalog JSON
/// (bundled assets or user-configured catalog URLs).
///
/// Commands run via `sh -c` can execute arbitrary code, so every command
/// from the catalog must pass this allowlist check before execution.
/// The check is fail-closed: anything unrecognized is rejected.
///
/// Design:
/// - Pipelines (`a | b`) are split and each segment is validated separately.
/// - Only known package-management binaries may lead a segment.
/// - Command substitution (`$(`, backticks), chained execution (`;`, `&&`,
///   `||`), and redirection (`>`, `<`) are rejected outright. Dynamic values
///   (e.g. distro codename) must be resolved in Dart before validation —
///   see `LinuxDistroResolver` — never via shell substitution.
class PackageCommandValidator {
  PackageCommandValidator._();

  /// Binaries allowed to lead a command segment. Package managers, repo
  /// tooling, and benign utilities only — anything else is rejected.
  static const Set<String> _allowedBinaries = {
    // Debian/Ubuntu package management
    'apt-get',
    'apt',
    'dpkg',
    'add-apt-repository',
    'apt-key',
    // RHEL/CentOS package management
    'dnf',
    'yum',
    'rpm',
    // Repo keys, sources, downloads
    'gpg',
    'tee',
    'curl',
    'wget',
    'echo',
    'sed',
    'mkdir',
    'touch',
    'chmod',
    'chown',
    'ln',
    // Elevation
    'sudo',
    'pkexec',
    // Service control (post-install hooks)
    'systemctl',
  };

  /// Substrings that must never appear anywhere in a catalog command.
  static const List<String> _forbiddenSubstrings = [
    '`', // command substitution
    r'$(',
    ';', // command chaining
    '&&',
    '||',
    '>', // redirection
    '<',
    // Defense-in-depth; the allowlist already blocks most of these
    'mkfs',
    ' dd ',
    'shutdown',
    'reboot',
    'eval ',
    'source ',
    'fork',
  ];

  /// Matches the leading binary of a segment: optional `sudo`/`pkexec`
  /// prefixes, then either an absolute path (`/usr/bin/apt-get`) or a bare
  /// name (`apt-get`). Group 1 = bare name, group 2 = path.
  static final RegExp _leadingBinary = RegExp(
    r'^(?:(?:sudo|pkexec)\s+)*(?:(/[\w.\-/]+)|([\w.\-]+))',
  );

  /// Validates a single shell command (one pipeline) from the catalog.
  ///
  /// Returns `null` if safe, otherwise a human-readable rejection reason.
  static String? validate(String command) {
    final trimmed = command.trim();
    if (trimmed.isEmpty) return 'Command is empty';

    for (final pattern in _forbiddenSubstrings) {
      if (trimmed.contains(pattern)) {
        return 'Forbidden pattern: "$pattern"';
      }
    }

    // Split the pipeline and validate every segment's leading binary.
    final segments = trimmed.split('|');
    for (final segment in segments) {
      final segTrimmed = segment.trim();
      if (segTrimmed.isEmpty) return 'Empty pipeline segment';

      final match = _leadingBinary.firstMatch(segTrimmed);
      if (match == null) return 'No leading binary in segment: "$segTrimmed"';

      final path = match.group(2);
      final binary = path != null ? path.split('/').last : (match.group(1)!);
      if (!_allowedBinaries.contains(binary)) {
        return 'Binary "$binary" is not in the allowed list';
      }
    }

    return null;
  }

  /// Validates a full command list for one distro.
  ///
  /// Returns the list of rejection reasons; empty means all commands passed.
  static List<String> validateAll(List<String> commands) {
    final errors = <String>[];
    for (final cmd in commands) {
      final reason = validate(cmd);
      if (reason != null) errors.add('"$cmd": $reason');
    }
    return errors;
  }
}
