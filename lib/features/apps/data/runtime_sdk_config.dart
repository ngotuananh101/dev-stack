/// Post-install wiring for SDK-style runtimes whose archives are not
/// self-configuring.
///
/// Node/PHP/Bun ship enough to be found on `PATH` alone. Go, Flutter and the
/// JDK do not: each has a tree of its own (`GOROOT`, the Flutter cache,
/// `JAVA_HOME`) whose location is derived from where its `bin/` lives, so the
/// install directory has to be in the environment before the first command
/// runs.
///
/// Kept separate from the installer service so the rules can be unit-tested
/// without a download, a filesystem, or a platform.
class RuntimeSdkConfig {
  const RuntimeSdkConfig._({
    required this.envVars,
    required this.pathDirs,
    required this.shims,
  });

  /// Environment variables to set for the current user.
  final Map<String, String> envVars;

  /// Directories to prepend to the user's `PATH`.
  final List<String> pathDirs;

  /// Names that should resolve to this SDK once [pathDirs] is on `PATH`.
  final List<String> shims;

  /// Returns the wiring for [appId], or `null` when the app configures
  /// itself the way every other runtime does.
  ///
  /// [installPath] is the flattened root: both SDK archives extract to a
  /// single top-level directory that the installer moves up, so `bin/` sits
  /// directly under it and `GOROOT` is [installPath] itself.
  static RuntimeSdkConfig? forApp(String appId, String installPath) {
    switch (appId) {
      case 'go':
        return RuntimeSdkConfig._(
          envVars: {'GOROOT': installPath},
          pathDirs: [_binDir(installPath)],
          shims: const ['go', 'gofmt'],
        );
      case 'flutter':
        return RuntimeSdkConfig._(
          envVars: const {},
          pathDirs: [_binDir(installPath)],
          shims: const ['flutter', 'dart'],
        );
      case 'java':
        return RuntimeSdkConfig._(
          envVars: {'JAVA_HOME': installPath},
          pathDirs: [_binDir(installPath)],
          shims: const ['java', 'javac', 'jar'],
        );
      default:
        return null;
    }
  }

  /// The file inside `bin/` that starts [appId], or `null` when the app wires
  /// nothing.
  ///
  /// Guessing `$appId.bat` on Windows would be wrong for the JDK: it ships
  /// `java.exe`, so the launcher would be reported missing even on a complete
  /// install.
  static String? launcherFile(String appId, {required bool isWindows}) {
    if (forApp(appId, '') == null) return null;
    switch (appId) {
      case 'go':
        return isWindows ? 'go.exe' : 'go';
      case 'flutter':
        return isWindows ? 'flutter.bat' : 'flutter';
      case 'java':
        return isWindows ? 'java.exe' : 'java';
      default:
        return null;
    }
  }

  /// The command that confirms the SDK is usable right after install, or
  /// `null` when nothing has to run.
  ///
  /// Flutter's archive does ship `bin/cache/dart-sdk` and a precompiled
  /// `flutter_tools.snapshot`, so nothing is downloaded here. The problem the
  /// first run solves is different: the launcher writes its cache lock and
  /// stamps, takes the archive's executable bits into account on the way, and
  /// fails loudly on a damaged or partially written extraction. Better that
  /// failure surfaces during install than the first time the user runs it.
  ///
  /// Java is the other way round: `java -version` starts the VM and reports
  /// the build it actually found, which catches an archive whose
  /// `lib/server/libjvm` did not survive extraction or a binary built for a
  /// newer libc than the machine has.
  ///
  /// `bin/flutter` is a shell script on Linux (executable as-is) and a batch
  /// file on Windows, which only `cmd` can run — hence [runInShell].
  static ({String executable, List<String> arguments, bool runInShell})?
  warmupCommand(
    String appId,
    String launcherPath, {
    required bool isWindows,
  }) {
    switch (appId) {
      case 'flutter':
        return (
          executable: launcherPath,
          arguments: const ['--version'],
          runInShell: isWindows,
        );
      case 'java':
        return (
          executable: launcherPath,
          arguments: const ['-version'],
          runInShell: isWindows,
        );
      default:
        return null;
    }
  }

  static String _binDir(String installPath) {
    final trimmed = installPath.replaceAll(RegExp(r'[\\/]+$'), '');
    final sep = trimmed.contains(r'\') && !trimmed.contains('/') ? r'\' : '/';
    return '$trimmed${sep}bin';
  }
}
