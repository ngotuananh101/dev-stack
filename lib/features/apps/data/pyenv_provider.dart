import 'dart:io';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'apps_provider.dart';
import '../domain/app_model.dart';
import 'package:dev_stack/core/services/log_service.dart';

part 'pyenv_provider.g.dart';

class PyenvState {
  final List<String> installedVersions;
  final String? activeVersion;

  PyenvState({required this.installedVersions, this.activeVersion});
}

@riverpod
class Pyenv extends _$Pyenv {
  @override
  Future<PyenvState> build() async {
    final installed = await _getInstalledVersions();
    final active = await _getActiveVersion();
    return PyenvState(installedVersions: installed, activeVersion: active);
  }

  /// Builds the environment variables required to run pyenv commands reliably.
  /// On Linux, setting PYENV_ROOT is mandatory; otherwise `bin/pyenv` defaults
  /// to `~/.pyenv` and fails to locate `libexec/` or `plugins/python-build`.
  @visibleForTesting
  static Map<String, String> buildPyenvEnvironment({
    required String installPath,
    bool? isWindows,
    Map<String, String>? currentEnv,
  }) {
    final windows = isWindows ?? Platform.isWindows;
    final env = Map<String, String>.from(currentEnv ?? Platform.environment);

    if (windows) {
      final pyenvWinDir = p.windows.join(installPath, 'pyenv-win');
      env['PYENV'] = pyenvWinDir;
      env['PYENV_HOME'] = pyenvWinDir;
      env['PYENV_ROOT'] = pyenvWinDir;
      final binDir = p.windows.join(pyenvWinDir, 'bin');
      final shimsDir = p.windows.join(pyenvWinDir, 'shims');
      final currentPath = env['Path'] ?? env['PATH'] ?? '';
      env['Path'] = '$binDir;$shimsDir;$currentPath';
    } else {
      env['PYENV_ROOT'] = installPath;
      final binDir = p.posix.join(installPath, 'bin');
      final shimsDir = p.posix.join(installPath, 'shims');
      final currentPath = env['PATH'] ?? '';
      env['PATH'] = '$binDir:$shimsDir:$currentPath';
    }

    return env;
  }

  /// Parses `pyenv install -l` (or `pyenv install --list`) stdout across
  /// Windows (`pyenv-win`) and Linux (`pyenv`), extracting latest patch versions
  /// per major.minor line and sorting in descending order.
  @visibleForTesting
  static List<String> parseInstallableVersions(String rawOutput) {
    final lines = rawOutput.split('\n');
    final versionList = <String>[];

    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty ||
          line.startsWith('Available') ||
          line.startsWith('::')) {
        continue;
      }
      // Match standard CPython semver versions (e.g. 3.12.4, 3.11.9, 2.7.18)
      if (RegExp(r'^\d+\.\d+\.\d+$').hasMatch(line)) {
        versionList.add(line);
      }
    }

    // Group by major.minor and keep latest patch version
    final latestVersions = <String, String>{};
    for (final v in versionList) {
      final parts = v.split('.');
      if (parts.length >= 2) {
        final key = '${parts[0]}.${parts[1]}';
        final currentLatest = latestVersions[key];
        if (currentLatest == null) {
          latestVersions[key] = v;
        } else {
          final curPatch =
              int.tryParse(
                currentLatest.split('.').elementAtOrNull(2) ?? '0',
              ) ??
              0;
          final newPatch = int.tryParse(parts.elementAtOrNull(2) ?? '0') ?? 0;
          if (newPatch > curPatch) {
            latestVersions[key] = v;
          }
        }
      }
    }

    // Sort descending by major.minor.patch
    final sorted = latestVersions.values.toList()
      ..sort((a, b) {
        final aParts = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
        final bParts = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
        for (var i = 0; i < 3; i++) {
          final aNum = i < aParts.length ? aParts[i] : 0;
          final bNum = i < bParts.length ? bParts[i] : 0;
          if (aNum != bNum) return bNum.compareTo(aNum);
        }
        return 0;
      });

    return sorted;
  }

  /// Parses `pyenv versions` output, stripping indicators (`*`),
  /// ignoring `system` and `current` pseudo-versions.
  @visibleForTesting
  static List<String> parseInstalledVersions(String rawOutput) {
    final lines = rawOutput.split('\n');
    final result = <String>[];

    for (final l in lines) {
      final line = l.trim();
      if (line.isEmpty) continue;
      final cleanLine = line.replaceAll('*', '').trim();
      final version = cleanLine.split(' ').first.trim();
      if (version.isNotEmpty &&
          version != 'current' &&
          version != 'system' &&
          !version.startsWith('(')) {
        result.add(version);
      }
    }

    return result;
  }

  /// Resolves the concrete executable to invoke for pyenv commands.
  /// On Linux, preferring `<installPath>/libexec/pyenv` or `<installPath>/bin/pyenv`
  /// ensures it executes the core script directly even if symlinks are unresolvable.
  @visibleForTesting
  static String resolvePyenvExecutable({
    required String installPath,
    String? cliFilePath,
    bool? isWindows,
  }) {
    final windows = isWindows ?? Platform.isWindows;
    if (windows) {
      return cliFilePath ??
          p.windows.join(installPath, 'pyenv-win', 'bin', 'pyenv.bat');
    }

    // On Linux, check libexec/pyenv first (the real script), then bin/pyenv
    final libexec = p.posix.join(installPath, 'libexec', 'pyenv');
    if (File(libexec).existsSync()) return libexec;

    final bin = p.posix.join(installPath, 'bin', 'pyenv');
    if (File(bin).existsSync() || Link(bin).existsSync()) return bin;

    return cliFilePath ?? bin;
  }

  Future<AppModel?> _getPyenvApp() async {
    final apps = await ref.read(appsProvider.future);
    return apps.where((a) => a.appId == 'pyenv').firstOrNull;
  }

  Future<String?> _getPyenvPath() async {
    final pyenvApp = await _getPyenvApp();
    if (pyenvApp == null || pyenvApp.location == null) {
      return pyenvApp?.cliFilePath;
    }
    return resolvePyenvExecutable(
      installPath: pyenvApp.location!,
      cliFilePath: pyenvApp.cliFilePath,
    );
  }

  Future<Map<String, String>?> _getEnvironment() async {
    final pyenvApp = await _getPyenvApp();
    if (pyenvApp == null || pyenvApp.location == null) return null;
    return buildPyenvEnvironment(installPath: pyenvApp.location!);
  }

  Future<String?> _getActiveVersion() async {
    final pyenvPath = await _getPyenvPath();
    final env = await _getEnvironment();
    if (pyenvPath == null) return null;

    try {
      final result = await Process.run(pyenvPath, [
        'versions',
      ], environment: env);
      if (result.exitCode == 0) {
        final lines = result.stdout.toString().split('\n');
        for (var line in lines) {
          final trimmed = line.trim();
          if (trimmed.startsWith('*')) {
            final active = trimmed.replaceAll('*', '').trim().split(' ').first;
            if (active != 'system') return active;
          }
        }
      }
    } catch (e) {
      AppLogger.warning('Failed to get active pyenv version: $e');
    }
    return null;
  }

  Future<List<String>> _getInstalledVersions() async {
    final pyenvPath = await _getPyenvPath();
    final env = await _getEnvironment();
    if (pyenvPath == null) return [];

    try {
      final result = await Process.run(pyenvPath, [
        'versions',
      ], environment: env);
      if (result.exitCode == 0) {
        return parseInstalledVersions(result.stdout.toString());
      }
    } catch (e) {
      AppLogger.error('Error listing pyenv versions: $e');
    }
    return [];
  }

  Future<List<String>> getInstallableVersions() async {
    final pyenvPath = await _getPyenvPath();
    final env = await _getEnvironment();
    if (pyenvPath == null) return [];

    try {
      // Run with environment containing PYENV_ROOT
      final result = await Process.run(pyenvPath, [
        'install',
        '-l',
      ], environment: env);
      if (result.exitCode == 0) {
        return parseInstallableVersions(result.stdout.toString());
      } else {
        AppLogger.warning(
          'pyenv install -l returned non-zero code (${result.exitCode}): ${result.stderr}',
        );
      }
    } catch (e) {
      AppLogger.error('Error listing installable versions: $e');
    }
    return [];
  }

  /// Last [maxLines] non-empty trailing lines of [text], for error
  /// reports. pyenv failures are long (a full build log), so only the tail
  /// -- where the "BUILD FAILED" banner, the log path and the check error
  /// live -- is kept.
  static String _tailLines(String text, int maxLines) {
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final tail = lines.length > maxLines
        ? lines.sublist(lines.length - maxLines)
        : lines;
    return tail.join('\n');
  }

  Future<void> installVersion(String version, {Function(String)? onLog}) async {
    final pyenvPath = await _getPyenvPath();
    final env = await _getEnvironment();
    if (pyenvPath == null) throw Exception('pyenv not found');

    onLog?.call('Starting installation of Python $version...');

    final result = await Process.run(pyenvPath, [
      'install',
      version,
    ], environment: env);
    if (result.exitCode != 0) {
      // pyenv splits the failure across both streams: the "BUILD FAILED"
      // banner and the python-build log path go to stdout, while the
      // post-install check error (e.g. a missing ssl extension) goes to
      // stderr. Keep the tail of both so the real reason is visible.
      final stdoutSummary = _tailLines(result.stdout.toString(), 4);
      final stderrSummary = _tailLines(result.stderr.toString(), 4);
      final summary = [
        if (stderrSummary.isNotEmpty) stderrSummary,
        if (stdoutSummary.isNotEmpty) stdoutSummary,
      ].join('\n');
      final stdoutTail = _tailLines(result.stdout.toString(), 20);
      final stderrTail = _tailLines(result.stderr.toString(), 20);
      final detail = [
        if (stdoutTail.isNotEmpty) '--- pyenv output ---\n$stdoutTail',
        if (stderrTail.isNotEmpty) '--- pyenv error ---\n$stderrTail',
      ].join('\n');
      final message = summary.isEmpty
          ? 'Failed to install Python $version (exit code ${result.exitCode})'
          : 'Failed to install Python $version (exit code ${result.exitCode}):\n$summary';
      onLog?.call('Error: ${detail.isEmpty ? message : detail}');
      AppLogger.error(
        'pyenv install $version failed: $message'
        '${detail.isEmpty ? '' : '\n$detail'}',
      );
      throw Exception(message);
    }

    onLog?.call('Successfully installed Python $version');
    ref.invalidateSelf();
  }

  Future<void> uninstallVersion(String version) async {
    final pyenvPath = await _getPyenvPath();
    final env = await _getEnvironment();
    if (pyenvPath == null) throw Exception('pyenv not found');

    final result = await Process.run(pyenvPath, [
      'uninstall',
      '-f',
      version,
    ], environment: env);
    if (result.exitCode != 0) {
      throw Exception('Failed to uninstall Python $version');
    }
    ref.invalidateSelf();
  }

  Future<void> globalVersion(String version) async {
    final pyenvPath = await _getPyenvPath();
    final env = await _getEnvironment();
    if (pyenvPath == null) throw Exception('pyenv not found');

    final result = await Process.run(pyenvPath, [
      'global',
      version,
    ], environment: env);
    if (result.exitCode != 0) {
      throw Exception('Failed to set global Python $version');
    }
    ref.invalidateSelf();
  }

  Future<String?> getCurrentVersion() async {
    final pyenvPath = await _getPyenvPath();
    final env = await _getEnvironment();
    if (pyenvPath == null) return null;

    final result = await Process.run(pyenvPath, ['version'], environment: env);
    if (result.exitCode == 0) {
      final ver = result.stdout.toString().split(' ').firstOrNull;
      if (ver != 'system') return ver;
    }
    return null;
  }
}
