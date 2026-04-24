import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:process_run/shell.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../features/settings/data/settings_provider.dart';
import '../config/app_config.dart';

part 'ssl_service.g.dart';

@riverpod
class SslService extends _$SslService {
  @override
  Future<bool> build() async {
    final settings = await ref.watch(settingsNotifierProvider.future);
    return settings.isSslInstalled;
  }

  String get _mkcertPath {
    // In production, we might need to use a different path
    // For now, assume it's in the binDir or baseBinDir
    final binPath = '${AppConfig.binDir}\\mkcert.exe';
    if (File(binPath).existsSync()) {
      return binPath;
    }
    
    // Fallback to absolute path from assets/bin if it exists in current working dir
    final localBinPath = '${Directory.current.path}\\assets\\bin\\mkcert.exe';
    return localBinPath;
  }

  Future<bool> checkStatus() async {
    try {
      final shell = Shell();
      final results = await shell.run('"$_mkcertPath" -CAROOT');
      return results.isNotEmpty && results.first.stdout.toString().trim().isNotEmpty;
    } catch (e) {
      debugPrint('SSL status check failed: $e');
      return false;
    }
  }

  Future<void> initializeRootCA() async {
    try {
      // Ensure the binary exists first
      if (!File(_mkcertPath).existsSync()) {
        debugPrint('mkcert.exe not found at $_mkcertPath');
        return;
      }

      final shell = Shell();
      // Use PowerShell to run as administrator to handle trust store and key saving
      final command = 'Start-Process -FilePath "$_mkcertPath" -ArgumentList "-install" -Verb RunAs -Wait';
      await shell.run('powershell -Command "$command"');
      
      // Refresh status and update settings
      final isInstalled = await checkStatus();
      if (isInstalled) {
        await ref.read(settingsNotifierProvider.notifier).updateField(isSslInstalled: true);
      }
      state = AsyncValue.data(isInstalled);
    } catch (e) {
      debugPrint('Failed to initialize Root CA: $e');
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> uninstallRootCA() async {
    try {
      if (!File(_mkcertPath).existsSync()) return;

      final shell = Shell();
      final command = 'Start-Process -FilePath "$_mkcertPath" -ArgumentList "-uninstall" -Verb RunAs -Wait';
      await shell.run('powershell -Command "$command"');
      
      // Update settings
      await ref.read(settingsNotifierProvider.notifier).updateField(isSslInstalled: false);
      state = const AsyncValue.data(false);
    } catch (e) {
      debugPrint('Failed to uninstall Root CA: $e');
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
}
