/// Fail-closed validator for legacy system PHP configuration commands.
///
/// Package installation and repository setup are never allowed. [validate]
/// also recognizes harmless read-only discovery queries for existing callers;
/// elevated execution must use [validateConfiguration] instead.
class PackageCommandValidator {
  PackageCommandValidator._();

  static const _forbiddenSubstrings = [
    '`',
    r'$(',
    ';',
    '&&',
    '||',
    '>',
    '<',
    'mkfs',
    ' dd ',
    'shutdown',
    'reboot',
    'eval ',
    'source ',
    'fork',
  ];

  static const _binaryPrefix = r'(?:/(?:usr/bin|usr/sbin|bin|sbin)/)?';
  static const _name = r'[a-z0-9][a-z0-9._+-]*';
  static const _phpIniDirectory =
      r'(?:'
      r'/etc/php\.d'
      r'|/etc/php/conf\.d'
      r'|/etc/php/\d+\.\d+/[a-z0-9_-]+/conf\.d'
      r'|/etc/opt/remi/php\d+/php\.d'
      r')';
  static final _iniTarget = RegExp('^$_phpIniDirectory/$_name\\.ini\$');
  static final _moduleTool = RegExp(
    '^${_binaryPrefix}php(?:en|dis)mod -v \\d+\\.\\d+ -s fpm $_name\$',
  );
  static final _iniWrite = RegExp(
    "^${_binaryPrefix}echo '(extension=$_name|zend_extension=$_name|opcache\\.enable=[01])' "
    "\\| ${_binaryPrefix}tee ($_phpIniDirectory/99-ponta-($_name)\\.ini)\$",
  );
  static final _iniComment = RegExp(
    "^${_binaryPrefix}sed -E -i 's,([^']+),\\\\x3b&,' '([^']+)'\$",
  );

  static String? _precheck(String command) {
    if (command.trim().isEmpty) return 'Command is empty';
    for (final pattern in _forbiddenSubstrings) {
      if (command.contains(pattern)) return 'Forbidden pattern: "$pattern"';
    }
    if (RegExp(r'[\n\r\v\f\x00]').hasMatch(command)) {
      return 'Command contains forbidden newline or vertical whitespace character';
    }
    return null;
  }

  /// Only module toggles, one owned ini assignment, or a comment-only ini edit.
  /// Matching the entire command prevents extra flags, targets and shell syntax
  /// from reaching the elevated shell. Paths must be plain children of a known
  /// PHP configuration directory, never traversal or arbitrary system files.
  static String? validateConfiguration(String command) {
    final error = _precheck(command);
    if (error != null) return error;
    final trimmed = command.trim();
    if (_moduleTool.hasMatch(trimmed)) return null;

    final write = _iniWrite.firstMatch(trimmed);
    if (write != null) {
      final assignment = write.group(1)!;
      final extension = assignment.startsWith('opcache.enable=')
          ? 'opcache'
          : assignment.split('=').last;
      if (extension == write.group(3)) return null;
    }

    final comment = _iniComment.firstMatch(trimmed);
    if (comment != null && _iniTarget.hasMatch(comment.group(2)!)) {
      final pattern = comment.group(1)!;
      if (pattern == r'^\s*opcache\.enable\s*=.*$') return null;
      const prefix = r'^\s*(zend_)?extension\s*=\s*"?(.*/)?';
      const suffix = r'(\.so)?"?\s*$';
      if (pattern.startsWith(prefix) && pattern.endsWith(suffix)) {
        final escapedName = pattern.substring(
          prefix.length,
          pattern.length - suffix.length,
        );
        final name = escapedName.replaceAll(r'\.', '.').replaceAll(r'\+', '+');
        if (RegExp('^$_name\$').hasMatch(name) &&
            RegExp.escape(name) == escapedName) {
          return null;
        }
      }
    }
    return 'PHP configuration command or target is not allowed';
  }

  /// Includes read-only discovery, but never package installation/update.
  static String? validate(String command) {
    final error = _precheck(command);
    if (error != null) return error;
    final trimmed = command.trim();
    if (validateConfiguration(trimmed) == null) return null;
    if (_isReadOnlyDiscovery(trimmed)) return null;
    if (trimmed.contains('tee') ||
        trimmed.contains('sed') ||
        trimmed.contains('phpenmod') ||
        trimmed.contains('phpdismod')) {
      return 'PHP configuration command or target is not allowed';
    }
    return 'Binary or command is not in the allowed list';
  }

  static bool _isReadOnlyDiscovery(String command) {
    // These queries are executed as direct argv by the manager, never a shell.
    // Exclude shell metacharacters and writable/update modes even here.
    if (!RegExp(r"^[a-zA-Z0-9_./+*^{}%\[\]=: '\\\-]+$").hasMatch(command)) {
      return false;
    }
    if (RegExp(
      '^${_binaryPrefix}apt-cache search (?:--names-only )?[a-zA-Z0-9_.+-]+\$',
    ).hasMatch(command)) {
      return true;
    }
    if (RegExp(
      "^${_binaryPrefix}apt-file list -x '?[a-zA-Z0-9_.^+\\\\-]+'?\$",
    ).hasMatch(command)) {
      return true;
    }
    if (RegExp(
      '^${_binaryPrefix}pacman (?:-Ss [a-zA-Z0-9_.+-]+|-Fl(?: $_name)*)\$',
    ).hasMatch(command)) {
      return true;
    }
    return RegExp(
      "^${_binaryPrefix}dnf repoquery (?:-l )?(?:--qf '[^']+' )?"
      "(?:-f '[a-zA-Z0-9_./+-]+'|'?$_name\\*?'?(?: '?$_name\\*?'?)*)\$",
    ).hasMatch(command);
  }

  static List<String> validateAll(List<String> commands) => [
    for (final command in commands)
      if (validate(command) case final String reason) '"$command": $reason',
  ];
}
