import 'dart:io';
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

  Future<SystemInfo> _fetchSystemInfo() async {
    // 1. Get raw systeminfo output using Process.run instead of Shell()
    final result = await Process.run('systeminfo', []);
    final rawOutput = result.stdout.toString();

    // 2. Get App details
    final packageInfo = await PackageInfo.fromPlatform();
    
    // 3. Get paths
    final appDir = Directory.current.path;
    final supportDir = await getApplicationSupportDirectory();

    return SystemInfo(
      rawOutput: rawOutput,
      appVersion: '${packageInfo.version}+${packageInfo.buildNumber}',
      frameworkVersion: 'Flutter (Windows)',
      dartVersion: Platform.version.split(' ')[0],
      databaseVersion: 'Isar 3.1.0',
      engineVersion: 'Chromium-based (Flutter)',
      appPath: appDir,
      userDataPath: supportDir.path,
      generatedAt: DateTime.now(),
    );
  }
}
