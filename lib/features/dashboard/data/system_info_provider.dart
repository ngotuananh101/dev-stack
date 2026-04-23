import 'dart:io';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:process_run/shell.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../core/config/app_config.dart';
import '../domain/system_info.dart';

part 'system_info_provider.g.dart';

@riverpod
class SystemInfoNotifier extends _$SystemInfoNotifier {
  @override
  Future<SystemInfo> build() async {
    return _fetchSystemInfo();
  }

  Future<SystemInfo> _fetchSystemInfo() async {
    final shell = Shell();
    final packageInfo = await PackageInfo.fromPlatform();
    String rawOutput = 'Scanning system information...';

    try {
      if (Platform.isWindows) {
        final result = await shell.run('systeminfo');
        if (result.isNotEmpty) {
          rawOutput = result.outText.trim();
        }
      } else {
        rawOutput = 'Systeminfo command is only available on Windows.';
      }
    } catch (e) {
      rawOutput = 'Error fetching system information: $e';
    }

    return SystemInfo(
      rawOutput: rawOutput,
      appVersion: packageInfo.version,
      frameworkVersion: 'Flutter (Windows)',
      dartVersion: Platform.version.split(' ').first,
      databaseVersion: 'Isar 3.1.0',
      engineVersion: 'Skia Engine',
      appPath: Platform.resolvedExecutable,
      userDataPath: AppConfig.baseDir,
      generatedAt: DateTime.now(),
    );
  }

  void refresh() {
    state = const AsyncValue.loading();
    _fetchSystemInfo().then((info) => state = AsyncValue.data(info));
  }
}
