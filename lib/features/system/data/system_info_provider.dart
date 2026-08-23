import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../domain/system_info.dart';

part 'system_info_provider.g.dart';

@riverpod
class SystemInfoNotifier extends _$SystemInfoNotifier {
  @override
  Future<SystemInfo> build() async {
    return _fetchSystemInfo();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchSystemInfo());
  }

  @visibleForTesting
  static Future<({String rawOutput, String frameworkLabel})>
      collectPlatformInfo({
    bool? isWindows,
    Future<ProcessResult> Function(String, List<String>)? run,
  }) async {
    final windows = isWindows ?? Platform.isWindows;
    final runner = run ?? Process.run;
    try {
      final res = windows
          ? await runner('systeminfo', [])
          : await runner('uname', ['-a']);
      return (
        rawOutput: res.stdout.toString(),
        frameworkLabel: windows ? 'Flutter (Windows)' : 'Flutter (Linux)',
      );
    } catch (_) {
      return (
        rawOutput: windows ? '' : 'system info unavailable',
        frameworkLabel: windows ? 'Flutter (Windows)' : 'Flutter (Linux)',
      );
    }
  }

  Future<SystemInfo> _fetchSystemInfo() async {
    final platformInfo = await collectPlatformInfo();

    final packageInfo = await PackageInfo.fromPlatform();
    final appDir = Directory.current.path;
    final supportDir = await getApplicationSupportDirectory();

    return SystemInfo(
      rawOutput: platformInfo.rawOutput,
      appVersion: '${packageInfo.version}+${packageInfo.buildNumber}',
      frameworkVersion: platformInfo.frameworkLabel,
      dartVersion: Platform.version.split(' ')[0],
      databaseVersion: 'Isar 3.1.0',
      engineVersion: 'Chromium-based (Flutter)',
      appPath: appDir,
      userDataPath: supportDir.path,
      generatedAt: DateTime.now(),
    );
  }
}

