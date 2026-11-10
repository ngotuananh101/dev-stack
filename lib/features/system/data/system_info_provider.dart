import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:isar_plus/isar_plus.dart' show Isar;
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../domain/build_info.dart';
import '../domain/system_info.dart';
import 'linux_system_probe.dart';

part 'system_info_provider.g.dart';

@riverpod
class SystemInfoState extends _$SystemInfoState {
  @override
  Future<SystemInfo> build() async {
    return _fetchSystemInfo();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchSystemInfo());
  }

  /// The raw platform block at the head of the report.
  ///
  /// Windows keeps `systeminfo` verbatim, because that dump is already the
  /// complete picture. Linux has no equivalent, so [LinuxSystemProbe] builds a
  /// structured report from procfs/sysfs and the tools that happen to be
  /// installed.
  @visibleForTesting
  static Future<String> collectRawOutput({
    bool? isWindows,
    Future<ProcessResult> Function(String, List<String>)? run,
    LinuxSystemProbe? linuxProbe,
  }) async {
    final runner = run ?? Process.run;
    if (isWindows ?? Platform.isWindows) {
      try {
        final res = await runner('systeminfo', []);
        return res.stdout.toString();
      } catch (_) {
        return '';
      }
    }

    final probe =
        linuxProbe ??
        LinuxSystemProbe(
          run: (exe, args) async => (await runner(exe, args)).stdout.toString(),
        );
    return probe.describe();
  }

  @visibleForTesting
  static Future<({String rawOutput, String operatingSystem})>
  collectPlatformInfo({
    bool? isWindows,
    Future<ProcessResult> Function(String, List<String>)? run,
    LinuxSystemProbe? linuxProbe,
  }) async {
    final windows = isWindows ?? Platform.isWindows;
    return (
      rawOutput: await collectRawOutput(
        isWindows: windows,
        run: run,
        linuxProbe: linuxProbe,
      ),
      operatingSystem: windows ? 'Windows' : 'Linux',
    );
  }

  /// The directory the user actually installed the app into.
  ///
  /// `Directory.current` is not it: a tarball, a `.deb` or a `.desktop` entry
  /// all start the binary from an unrelated working directory, and inside an
  /// AppImage the executable lives under an ephemeral `/tmp/.mount_*` path that
  /// disappears on exit. The AppImage file itself is the honest answer there.
  @visibleForTesting
  static String resolveAppPath({
    String? resolvedExecutable,
    String? appImage,
    bool? isWindows,
  }) {
    final windows = isWindows ?? Platform.isWindows;
    final context = windows ? p.windows : p.posix;
    final executable = resolvedExecutable ?? Platform.resolvedExecutable;
    final appImagePath = appImage ?? Platform.environment['APPIMAGE'];

    final target = (appImagePath == null || appImagePath.isEmpty)
        ? executable
        : appImagePath;
    return context.dirname(target);
  }

  Future<SystemInfo> _fetchSystemInfo() async {
    final platformInfo = await collectPlatformInfo();
    final buildInfo = _buildInfo();
    final appVersion = await _appVersion();

    final supportDir = await getApplicationSupportDirectory();

    return SystemInfo(
      rawOutput: platformInfo.rawOutput,
      buildInfo: buildInfo,
      appVersion: appVersion,
      frameworkVersion: buildInfo.frameworkLabel(platformInfo.operatingSystem),
      dartVersion: Platform.version.split(' ')[0],
      databaseVersion: 'isar_plus ${Isar.version}',
      engineVersion: buildInfo.engineLabel,
      appPath: resolveAppPath(),
      userDataPath: supportDir.path,
      generatedAt: DateTime.now(),
    );
  }

  /// Compile-time constants, so the lookup is a plain map read at runtime.
  static BuildInfo _buildInfo() => BuildInfo.fromValues(const {
    'BUILD_TIME': String.fromEnvironment('BUILD_TIME'),
    'BUILD_SHA': String.fromEnvironment('BUILD_SHA'),
    'BUILD_BRANCH': String.fromEnvironment('BUILD_BRANCH'),
    'BUILD_DIRTY': String.fromEnvironment('BUILD_DIRTY'),
    'FRAMEWORK_VERSION': String.fromEnvironment('FRAMEWORK_VERSION'),
    'FRAMEWORK_REVISION': String.fromEnvironment('FRAMEWORK_REVISION'),
    'ENGINE_REVISION': String.fromEnvironment('ENGINE_REVISION'),
    'ENGINE_COMMIT_DATE': String.fromEnvironment('ENGINE_COMMIT_DATE'),
  });

  /// `1.2.0+3`, or a placeholder when the package metadata is unavailable.
  static Future<String> _appVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return '${packageInfo.version}+${packageInfo.buildNumber}';
    } catch (_) {
      return 'unknown';
    }
  }
}
