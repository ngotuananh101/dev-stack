import 'dart:io';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:path/path.dart' as p;
import '../../features/settings/data/settings_provider.dart';
import '../config/app_config.dart';
import 'package:dev_stack/core/services/log_service.dart';

part 'ssl_service.g.dart';

@riverpod
class SslService extends _$SslService {
  @override
  Future<bool> build() async {
    // Safely listen to settings changes and update state manually
    ref.listen(settingsNotifierProvider, (previous, next) {
      next.whenData((settings) {
        state = AsyncValue.data(settings.isSslInstalled);
      });
    });

    final settings = await ref.read(settingsNotifierProvider.future);
    return settings.isSslInstalled;
  }

  bool get isInstalled => state.value ?? false;

  String get mkcertPath {
    final binPath = p.join(AppConfig.binDir, 'mkcert.exe');
    if (File(binPath).existsSync()) {
      return binPath;
    }

    final devPath = p.join(Directory.current.path, 'assets', 'bin', 'mkcert.exe');
    if (File(devPath).existsSync()) {
      return devPath;
    }

    final prodPath = p.join(
      p.dirname(Platform.resolvedExecutable),
      'data',
      'flutter_assets',
      'assets',
      'bin',
      'mkcert.exe',
    );
    if (File(prodPath).existsSync()) {
      return prodPath;
    }

    return devPath;
  }

  Future<bool> checkStatus() async {
    try {
      final result = await Process.run(mkcertPath, ['-CAROOT']);
      final output = result.stdout.toString().trim();
      return result.exitCode == 0 && output.isNotEmpty;
    } catch (e) {
      AppLogger.error('SSL status check failed: $e');
      return false;
    }
  }

  String getSiteCertDir(String domain) => p.join(AppConfig.certsDir, domain);
  String getSiteCertPath(String domain) => p.join(getSiteCertDir(domain), 'cert.pem');
  String getSiteKeyPath(String domain) => p.join(getSiteCertDir(domain), 'key.pem');

  Future<void> generateSiteCert(String domain, {bool force = false}) async {
    if (!isInstalled) return;

    final certPath = getSiteCertPath(domain);
    final keyPath = getSiteKeyPath(domain);

    if (!force && File(certPath).existsSync() && File(keyPath).existsSync()) {
      AppLogger.info('Certificate for $domain already exists, skipping generation.');
      return;
    }

    final dir = Directory(getSiteCertDir(domain));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }

    try {
      await Process.run(
        mkcertPath,
        ['-cert-file', 'cert.pem', '-key-file', 'key.pem', domain, 'localhost', '127.0.0.1', '::1'],
        workingDirectory: dir.path,
      );
      AppLogger.info('Successfully generated certificate for $domain');
    } catch (e) {
      AppLogger.error('Failed to generate certificate for $domain: $e');
    }
  }

  Future<void> initializeRootCA() async {
    // Wait for the build process to finish so we have the correct state
    await future;

    if (state.value == true) {
      // Already marked as installed in DB, just ensure localhost cert exists
      await generateSiteCert('localhost');
      return;
    }

    // Double check actual system status before running expensive install command
    final isActuallyInstalled = await checkStatus();
    if (isActuallyInstalled) {
      AppLogger.info('SSL is already installed in system, updating database status...');
      await ref.read(settingsNotifierProvider.notifier).updateField(isSslInstalled: true);
      state = const AsyncValue.data(true);
      await generateSiteCert('localhost');
      return;
    }
    
    try {
      if (!File(mkcertPath).existsSync()) {
        AppLogger.info('mkcert.exe not found at $mkcertPath');
        return;
      }

      AppLogger.info('SSL not found, running mkcert -install...');
      final psCommand =
          "Start-Process -FilePath '$mkcertPath' -ArgumentList '-install' -Verb RunAs -Wait";
      await Process.run('powershell', ['-Command', psCommand]);

      final isInstalledNow = await checkStatus();
      if (isInstalledNow) {
        final settingsNotifier = ref.read(settingsNotifierProvider.notifier);
        await settingsNotifier.updateField(isSslInstalled: true);
        await generateSiteCert('localhost');
      }
      state = AsyncValue.data(isInstalledNow);
    } catch (e) {
      AppLogger.error('Failed to initialize Root CA: $e');
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> uninstallRootCA() async {
    try {
      if (!File(mkcertPath).existsSync()) return;

      final psCommand =
          "Start-Process -FilePath '$mkcertPath' -ArgumentList '-uninstall' -Verb RunAs -Wait";
      await Process.run('powershell', ['-Command', psCommand]);
      
      await ref.read(settingsNotifierProvider.notifier).updateField(isSslInstalled: false);
      state = const AsyncValue.data(false);
    } catch (e) {
      AppLogger.error('Failed to uninstall Root CA: $e');
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
}
