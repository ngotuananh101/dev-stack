import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:path/path.dart' as p;
import '../../features/settings/data/settings_provider.dart';
import '../config/app_config.dart';
import 'package:dev_stack/core/services/background_process.dart';
import 'package:dev_stack/core/services/log_service.dart';

part 'ssl_service.g.dart';

@Riverpod(keepAlive: true)
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

  /// Bundled mkcert asset name for the host platform. Windows keeps the
  /// legacy unversioned `mkcert.exe`; Linux picks the versioned binary whose
  /// architecture matches the Dart VM (`Platform.version` embeds `linux_x64`,
  /// `linux_arm64`, ...), defaulting to amd64.
  @visibleForTesting
  static String mkcertAssetBasename({bool? isLinux, String? dartVersion}) {
    final linux = isLinux ?? Platform.isLinux;
    if (!linux) return 'mkcert.exe';
    final version = dartVersion ?? Platform.version;
    if (version.contains('arm64')) return 'mkcert-v1.4.4-linux-arm64';
    if (RegExp(r'arm(?!64)').hasMatch(version)) {
      return 'mkcert-v1.4.4-linux-arm';
    }
    return 'mkcert-v1.4.4-linux-amd64';
  }

  String get mkcertPath {
    final binCopy = p.join(AppConfig.binDir, 'mkcert');
    final assetName = mkcertAssetBasename();

    // Windows resolution is unchanged: prefer an installed copy, then the
    // dev/prod asset copies of mkcert.exe.
    if (!Platform.isLinux) {
      final binPath = p.join(AppConfig.binDir, 'mkcert.exe');
      if (File(binPath).existsSync()) return binPath;

      final devPath = p.join(
          Directory.current.path, 'assets', 'bin', 'mkcert.exe');
      if (File(devPath).existsSync()) return devPath;

      final prodPath = p.join(
        p.dirname(Platform.resolvedExecutable),
        'data',
        'flutter_assets',
        'assets',
        'bin',
        'mkcert.exe',
      );
      if (File(prodPath).existsSync()) return prodPath;
      return devPath;
    }

    // Linux: asset-bundle files are not executable, so materialise a copy
    // into ~/.ponta/bin and mark it +x. Re-copy when the asset changed size
    // (version upgrade).
    final candidates = [
      p.join(AppConfig.binDir, assetName),
      p.join(Directory.current.path, 'assets', 'bin', assetName),
      p.join(
        p.dirname(Platform.resolvedExecutable),
        'data',
        'flutter_assets',
        'assets',
        'bin',
        assetName,
      ),
    ];
    final source = candidates
        .map((p) => File(p))
        .firstWhere((f) => f.existsSync(), orElse: () => File(''));
    if (source.path.isEmpty) return binCopy;

    try {
      final target = File(binCopy);
      final needsCopy = !target.existsSync() ||
          target.lengthSync() != source.lengthSync();
      if (needsCopy) {
        if (!Directory(AppConfig.binDir).existsSync()) {
          Directory(AppConfig.binDir).createSync(recursive: true);
        }
        source.copySync(binCopy);
        Process.runSync('chmod', ['755', binCopy]);
      }
    } catch (_) {}
    return binCopy;
  }

  Future<bool> checkStatus() async {
    try {
      // First check if CAROOT exists
      final carootResult = await BackgroundProcess.run(mkcertPath, ['-CAROOT']);
      if (carootResult.exitCode != 0 ||
          carootResult.stdout.toString().trim().isEmpty) {
        AppLogger.info('CAROOT not found or invalid');
        return false;
      }

      // Now verify the CA is actually installed in the system trust store
      // We do this by attempting to generate a test certificate and checking
      // if mkcert warns about the CA not being installed
      final nullDevice = Platform.isWindows ? 'nul' : '/dev/null';
      final testResult = await BackgroundProcess.run(mkcertPath, [
        '-cert-file',
        nullDevice,
        '-key-file',
        nullDevice,
        'test.local',
      ]);

      final stdout = testResult.stdout.toString();
      final stderr = testResult.stderr.toString();
      final combinedOutput = stdout + stderr;

      // If mkcert warns about CA not being installed, return false
      if (combinedOutput.contains('local CA is not installed') ||
          combinedOutput.contains('Run "mkcert -install"')) {
        AppLogger.warning(
          'CAROOT exists but CA is not installed in system trust store',
        );
        return false;
      }

      AppLogger.info('SSL Root CA is properly installed and trusted');
      return true;
    } catch (e) {
      AppLogger.error('SSL status check failed: $e');
      return false;
    }
  }

  String getSiteCertDir(String domain) => p.join(AppConfig.certsDir, domain);
  String getSiteCertPath(String domain) =>
      p.join(getSiteCertDir(domain), 'cert.pem');
  String getSiteKeyPath(String domain) =>
      p.join(getSiteCertDir(domain), 'key.pem');

  Future<void> generateSiteCert(String domain, {bool force = false}) async {
    if (!isInstalled) return;

    final certPath = getSiteCertPath(domain);
    final keyPath = getSiteKeyPath(domain);

    if (!force && File(certPath).existsSync() && File(keyPath).existsSync()) {
      AppLogger.info(
        'Certificate for $domain already exists, skipping generation.',
      );
      return;
    }

    final dir = Directory(getSiteCertDir(domain));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }

    try {
      await BackgroundProcess.run(mkcertPath, [
        '-cert-file',
        'cert.pem',
        '-key-file',
        'key.pem',
        domain,
        'localhost',
        '127.0.0.1',
        '::1',
      ], workingDirectory: dir.path);
      AppLogger.info('Successfully generated certificate for $domain');
    } catch (e) {
      AppLogger.error('Failed to generate certificate for $domain: $e');
    }
  }

  Future<void> initializeRootCA() async {
    // Wait for the build process to finish so we have the correct state
    await future;

    // Always verify actual system status, even if DB says installed
    // This catches cases where DB is out of sync with reality
    final isActuallyInstalled = await checkStatus();

    if (isActuallyInstalled) {
      // CA is properly installed and trusted
      if (state.value != true) {
        AppLogger.info(
          'SSL is already installed in system, updating database status...',
        );
        await ref
            .read(settingsNotifierProvider.notifier)
            .updateField(isSslInstalled: true);
        state = const AsyncValue.data(true);
      }
      await generateSiteCert('localhost');
      return;
    }

    // If DB says installed but checkStatus() says not, log the discrepancy
    if (state.value == true) {
      AppLogger.warning(
        'Database says SSL is installed, but verification failed. Will attempt reinstall...',
      );
    }

    try {
      if (!File(mkcertPath).existsSync()) {
        AppLogger.info('mkcert binary not found at $mkcertPath');
        return;
      }

      AppLogger.info('SSL not found, running mkcert -install...');

      final result = await BackgroundProcess.runElevated(mkcertPath, const [
        '-install',
      ]);

      AppLogger.info('mkcert -install exit code: ${result.exitCode}');

      if (result.exitCode != 0) {
        AppLogger.error(
          'mkcert -install failed with exit code ${result.exitCode}',
        );
        state = AsyncValue.error(
          Exception(
            'mkcert installation failed with exit code ${result.exitCode}',
          ),
          StackTrace.current,
        );
        return;
      }

      final isInstalledNow = await checkStatus();
      if (isInstalledNow) {
        final settingsNotifier = ref.read(settingsNotifierProvider.notifier);
        await settingsNotifier.updateField(isSslInstalled: true);
        await generateSiteCert('localhost');
        AppLogger.info('SSL Root CA successfully installed and trusted');
      } else {
        AppLogger.error(
          'mkcert -install succeeded but checkStatus() still returns false',
        );
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

      AppLogger.info('Uninstalling SSL Root CA...');

      final result = await BackgroundProcess.runElevated(mkcertPath, const [
        '-uninstall',
      ]);

      AppLogger.info('mkcert -uninstall exit code: ${result.exitCode}');

      if (result.exitCode != 0) {
        AppLogger.error(
          'mkcert -uninstall failed with exit code ${result.exitCode}',
        );
        state = AsyncValue.error(
          Exception(
            'mkcert uninstallation failed with exit code ${result.exitCode}',
          ),
          StackTrace.current,
        );
        return;
      }

      await ref
          .read(settingsNotifierProvider.notifier)
          .updateField(isSslInstalled: false);
      state = const AsyncValue.data(false);
      AppLogger.info('SSL Root CA successfully uninstalled');
    } catch (e) {
      AppLogger.error('Failed to uninstall Root CA: $e');
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
}
