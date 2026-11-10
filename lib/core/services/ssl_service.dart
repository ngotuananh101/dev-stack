import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:path/path.dart' as p;
import '../../features/settings/data/settings_provider.dart';
import '../config/app_config.dart';
import 'package:dev_stack/core/services/background_process.dart';
import 'package:dev_stack/core/services/log_service.dart';
import 'package:dev_stack/core/services/ssl_install_declines.dart';

part 'ssl_service.g.dart';

@Riverpod(keepAlive: true)
class SslService extends _$SslService {
  @override
  Future<bool> build() async {
    // Safely listen to settings changes and update state manually
    ref.listen(settingsProvider, (previous, next) {
      next.whenData((settings) {
        state = AsyncValue.data(settings.isSslInstalled);
      });
    });

    final settings = await ref.read(settingsProvider.future);
    return settings.isSslInstalled;
  }

  bool get _isInstalled => state.value ?? false;

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

  String get _mkcertPath {
    final binCopy = p.join(AppConfig.binDir, 'mkcert');
    final assetName = mkcertAssetBasename();

    // Windows resolution is unchanged: prefer an installed copy, then the
    // dev/prod asset copies of mkcert.exe.
    if (!Platform.isLinux) {
      final binPath = p.join(AppConfig.binDir, 'mkcert.exe');
      if (File(binPath).existsSync()) return binPath;

      final devPath = p.join(
        Directory.current.path,
        'assets',
        'bin',
        'mkcert.exe',
      );
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
      final needsCopy =
          !target.existsSync() || target.lengthSync() != source.lengthSync();
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
      // `mkcert -CAROOT` prints the configured path even before a CA has been
      // created, so checking its output alone would make this method create a
      // CA as a side effect of the certificate-generation probe below.
      final carootResult = await BackgroundProcess.run(_mkcertPath, [
        '-CAROOT',
      ]);
      final carootPath = carootResult.stdout.toString().trim();
      final rootCaPath = p.join(carootPath, 'rootCA.pem');
      if (carootResult.exitCode != 0 ||
          carootPath.isEmpty ||
          !File(rootCaPath).existsSync()) {
        AppLogger.info('CAROOT not found or invalid');
        return false;
      }

      if (Platform.isLinux) {
        return await _checkLinuxSystemTrust(rootCaPath);
      }

      // Now verify the CA is actually installed in the system trust store
      // We do this by attempting to generate a test certificate and checking
      // if mkcert warns about the CA not being installed
      final nullDevice = Platform.isWindows ? 'nul' : '/dev/null';
      final testResult = await BackgroundProcess.run(_mkcertPath, [
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

  /// Linux exposes its system trust store as one of these PEM bundles. Verify
  /// the mkcert root against them instead of asking mkcert to create a throwaway
  /// certificate: mkcert's warning is not a reliable status API when it runs
  /// unprivileged from an AppImage after a separate pkexec installation.
  Future<bool> _checkLinuxSystemTrust(String rootCaPath) async {
    if (await isRootCaTrusted(rootCaPath)) {
      AppLogger.info('SSL Root CA is properly installed and trusted');
      return true;
    }

    AppLogger.warning(
      'CAROOT exists but CA is not installed in system trust store',
    );
    return false;
  }

  /// Whether [rootCaPath] — a self-signed CA — is present in one of the PEM
  /// bundles in [bundles], defaulting to [linuxTrustStoreBundles].
  ///
  /// `openssl verify` builds a chain towards a *target* certificate, and its
  /// builder treats that target as an end entity: presenting the root CA
  /// itself reports `error 18 at 0 depth lookup: self-signed certificate` even
  /// when the exact certificate is an anchor in the bundle. That is a false
  /// negative — the CA is installed, the site's certificates verify against
  /// it, and browsers trust them — which made every mkcert install look
  /// failed. `-partial_chain` lets the anchor end the chain, so the answer
  /// reflects whether the CA is in the store while an uninstalled CA (even one
  /// sharing the same subject, as repeated mkcert installs produce) still
  /// fails verification.
  @visibleForTesting
  static Future<bool> isRootCaTrusted(
    String rootCaPath, {
    List<String>? bundles,
  }) async {
    for (final trustStore in bundles ?? linuxTrustStoreBundles()) {
      if (!File(trustStore).existsSync()) continue;

      final result = await BackgroundProcess.run('openssl', [
        'verify',
        '-partial_chain',
        '-CAfile',
        trustStore,
        rootCaPath,
      ]);
      if (result.exitCode == 0) return true;
    }
    return false;
  }

  @visibleForTesting
  static List<String> linuxTrustStoreBundles() => const [
    '/etc/ssl/certs/ca-certificates.crt', // Debian, Ubuntu
    '/etc/pki/tls/certs/ca-bundle.crt', // RHEL, Fedora
    '/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem',
    '/etc/ssl/ca-bundle.pem', // SUSE
    '/etc/ssl/cert.pem', // Alpine, Arch
  ];

  /// The command that installs `certutil`, which mkcert needs to add its CA to
  /// the Firefox and Chrome (NSS) stores. The package name differs per family:
  /// `libnss3-tools` is the Debian/Ubuntu spelling, and printing it on a Fedora
  /// host sends the user to an `apt` that does not exist there.
  @visibleForTesting
  static String certutilInstallHint({
    String? osReleaseId,
    String? osReleaseIdLike,
  }) {
    final id = (osReleaseId ?? _osReleaseValue('ID')).toLowerCase();
    final idLike = (osReleaseIdLike ?? _osReleaseValue('ID_LIKE'))
        .toLowerCase();
    final family = '$id $idLike';

    if (family.contains('debian') || family.contains('ubuntu')) {
      return 'sudo apt install libnss3-tools';
    }
    if (family.contains('fedora') ||
        family.contains('rhel') ||
        family.contains('centos') ||
        family.contains('suse')) {
      return 'sudo dnf install nss-tools';
    }
    if (id == 'arch' || idLike.contains('arch')) {
      return 'sudo pacman -S nss';
    }
    if (id == 'alpine') {
      return 'sudo apk add nss-tools';
    }
    return 'install your distro\'s nss-tools package (it provides certutil)';
  }

  /// The package that provides `certutil` on the host family, with the package
  /// manager that installs it. Returns null for a family the app does not know
  /// how to install on, so the caller offers the command instead of guessing.
  @visibleForTesting
  static ({String packageManager, String packageName})? nssToolsPackageManager({
    String? osReleaseId,
    String? osReleaseIdLike,
  }) {
    final id = (osReleaseId ?? _osReleaseValue('ID')).toLowerCase();
    final idLike = (osReleaseIdLike ?? _osReleaseValue('ID_LIKE'))
        .toLowerCase();
    final family = '$id $idLike';

    if (family.contains('debian') || family.contains('ubuntu')) {
      // apt-get rather than apt: the app runs this non-interactively, and
      // apt's "unstable CLI interface" warning is aimed at humans typing it.
      return (packageManager: 'apt-get', packageName: 'libnss3-tools');
    }
    if (family.contains('fedora') ||
        family.contains('rhel') ||
        family.contains('centos')) {
      return (packageManager: 'dnf', packageName: 'nss-tools');
    }
    if (family.contains('suse')) {
      return (packageManager: 'zypper', packageName: 'nss-tools');
    }
    if (id == 'arch' || idLike.contains('arch')) {
      return (packageManager: 'pacman', packageName: 'nss');
    }
    if (id == 'alpine') {
      return (packageManager: 'apk', packageName: 'nss-tools');
    }
    return null;
  }

  /// The argv that refreshes [packageManager]'s index. Non-interactive in every
  /// case: the elevated runner gives the process no terminal to answer a
  /// prompt on, so a confirmation question would hang until pkexec is killed.
  @visibleForTesting
  static List<String> packageRefreshArgs(String packageManager) {
    switch (packageManager) {
      case 'dnf':
        return ['makecache', '--refresh', '-y'];
      case 'apt-get':
        return ['update', '-y'];
      case 'pacman':
        return ['-Sy', '--noconfirm'];
      case 'apk':
        return ['update'];
      case 'zypper':
        return ['--non-interactive', 'refresh'];
      default:
        return const [];
    }
  }

  /// The argv that installs [packageName] with [packageManager]. `--assume-yes`
  /// / `-y` is what keeps the install from stopping on a prompt that nothing
  /// can answer.
  @visibleForTesting
  static List<String> packageInstallArgs(
    String packageManager,
    String packageName, {
    bool assumeYes = true,
  }) {
    switch (packageManager) {
      case 'dnf':
        return ['install', if (assumeYes) '-y', packageName];
      case 'apt-get':
        return ['install', if (assumeYes) '-y', packageName];
      case 'pacman':
        return ['-S', if (assumeYes) '--noconfirm', packageName];
      case 'apk':
        return ['add', packageName];
      case 'zypper':
        return [
          '--non-interactive',
          'install',
          if (assumeYes) '-y',
          packageName,
        ];
      default:
        return const [];
    }
  }

  /// Whether `certutil` — the NSS store tool mkcert needs for Firefox and
  /// Chrome — is on the PATH.
  @visibleForTesting
  static Future<bool> isCertutilAvailable() async {
    try {
      final result = await BackgroundProcess.run('which', ['certutil']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// A privileged step waiting on the user's approval.
  ///
  /// [command] is the real command line, not a description: the prompt exists
  /// so they can see what is about to run with administrator rights.
  static String _describeCommand(String executable, List<String> arguments) {
    String quote(String value) => RegExp(r'[\s"$`\\]').hasMatch(value)
        ? '"${value.replaceAll(r'\', r'\\').replaceAll('"', r'\"').replaceAll(r'$', r'\$').replaceAll('`', r'\`')}"'
        : value;
    return [executable, ...arguments].map(quote).join(' ');
  }

  SslInstallDeclines get _declines =>
      SslInstallDeclines(p.join(AppConfig.dataDir, 'ssl', 'declines.json'));

  static String _osReleaseValue(String key) {
    try {
      final file = File('/etc/os-release');
      if (!file.existsSync()) return '';
      for (final line in file.readAsLinesSync()) {
        if (line.startsWith('$key=')) {
          return line
              .substring(key.length + 1)
              .trim()
              .replaceAll(RegExp(r'''^["']|["']$'''), '');
        }
      }
    } catch (_) {}
    return '';
  }

  String getSiteCertDir(String domain) => p.join(AppConfig.certsDir, domain);
  String getSiteCertPath(String domain) =>
      p.join(getSiteCertDir(domain), 'cert.pem');
  String getSiteKeyPath(String domain) =>
      p.join(getSiteCertDir(domain), 'key.pem');

  Future<void> generateSiteCert(String domain, {bool force = false}) async {
    if (!_isInstalled) return;

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

    // `Process.run` reports an ordinary non-zero exit as a result, not as a
    // thrown error, so the exit code has to be checked: mkcert failing (no CA,
    // permission denied, bad domain) used to log success and let the caller
    // write an SSL vhost pointing at files that were never created.
    try {
      final result = await BackgroundProcess.run(_mkcertPath, [
        '-cert-file',
        'cert.pem',
        '-key-file',
        'key.pem',
        domain,
        'localhost',
        '127.0.0.1',
        '::1',
      ], workingDirectory: dir.path);
      if (result.exitCode != 0) {
        AppLogger.error(
          'Failed to generate certificate for $domain: mkcert exited with '
          'code ${result.exitCode}: ${result.stderr}',
        );
        return;
      }
      if (!File(certPath).existsSync() || !File(keyPath).existsSync()) {
        AppLogger.error(
          'mkcert reported success for $domain but did not write '
          'cert.pem/key.pem in ${dir.path}',
        );
        return;
      }
      AppLogger.info('Successfully generated certificate for $domain');
    } catch (e) {
      AppLogger.error('Failed to generate certificate for $domain: $e');
    }
  }

  Future<String> _resolveCaroot() async {
    try {
      final res = await BackgroundProcess.run(_mkcertPath, const ['-CAROOT']);
      final out = res.stdout.toString().trim();
      if (out.isNotEmpty) return out;
    } catch (_) {}
    return p.join(
      Platform.environment['HOME'] ?? '~',
      '.local',
      'share',
      'mkcert',
    );
  }

  /// Builds elevated execution arguments for mkcert.
  ///
  /// On Linux, pkexec strips environment variables and executes as root (whose
  /// CAROOT is `/root/.local/share/mkcert`). We forward the user's explicit
  /// [carootPath] via shell positional arguments so root installs the user's CA into
  /// the system store, and chowns [carootPath] back to [username] so the user retains
  /// full read/write ownership of the CA key.
  ///
  /// On Windows, mkcert is executed directly with elevation via PowerShell RunAs.
  @visibleForTesting
  static ({String executable, List<String> arguments}) buildElevatedMkcertArgs({
    required String mkcertPath,
    required String carootPath,
    required String action,
    String? username,
    bool? isLinux,
  }) {
    final onLinux = isLinux ?? Platform.isLinux;
    if (onLinux) {
      return (
        executable: 'sh',
        arguments: [
          '-c',
          'set -e; export CAROOT="\$1"; "\$2" "\$3"; if [ -n "\$4" ]; then chown -R "\$4" "\$1" 2>/dev/null || true; fi',
          'sh',
          carootPath,
          mkcertPath,
          action,
          username ?? '',
        ],
      );
    }
    return (executable: mkcertPath, arguments: [action]);
  }

  /// [askPermission] is called before anything runs with administrator rights
  /// and must return true to go ahead. At startup it shows a dialog; from the
  /// Settings page the user has already asked for the install, so it can be a
  /// function returning true. When null, privileged steps are skipped
  /// entirely: installing a root CA or a system package must never happen
  /// without the user saying yes.
  Future<void> initializeRootCA({
    Future<bool> Function(SslInstallPrompt prompt)? askPermission,
  }) async {
    // Wait for the build process to finish so we have the correct state
    await future;

    final declines = _declines;
    final username =
        Platform.environment['USER'] ?? Platform.environment['LOGNAME'] ?? '';
    final userCaroot = await _resolveCaroot();
    final elevatedCmd = buildElevatedMkcertArgs(
      mkcertPath: _mkcertPath,
      carootPath: userCaroot,
      action: '-install',
      username: username,
    );

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
            .read(settingsProvider.notifier)
            .updateField(isSslInstalled: true);
        state = const AsyncValue.data(true);
      }
      await generateSiteCert('localhost');
      // The NSS store is a separate trust store from the system one: the CA
      // can be installed and trusted everywhere except Firefox and Chrome.
      await _ensureCertutil(askPermission: askPermission);
      return;
    }

    // If DB says installed but checkStatus() says not, log the discrepancy
    if (state.value == true) {
      AppLogger.warning(
        'Database says SSL is installed, but verification failed. Will attempt reinstall...',
      );
    }

    try {
      if (!File(_mkcertPath).existsSync()) {
        AppLogger.info('mkcert binary not found at $_mkcertPath');
        return;
      }

      if (askPermission == null) {
        AppLogger.info(
          'SSL is not installed and no permission prompt was provided; '
          'leaving the system trust store untouched',
        );
        return;
      }

      // The certificate authority has to exist before it can be trusted, so
      // the unprivileged run happens first: it creates the CA in the user's
      // CAROOT and adds it to that user's NSS stores.
      final userInit = await BackgroundProcess.run(_mkcertPath, const [
        '-install',
      ]);
      final userInitOutput = '${userInit.stdout}${userInit.stderr}'
          .toLowerCase();

      var wroteToSystemStore = false;
      if (!await declines.isDeclined(SslInstallDeclines.rootCa)) {
        final allowed = await askPermission(
          _rootCaPrompt(elevatedCmd.executable, elevatedCmd.arguments),
        );
        if (!allowed) {
          await declines.decline(SslInstallDeclines.rootCa);
          AppLogger.info(
            'User declined installing the root CA into the system trust store',
          );
        } else {
          AppLogger.info('SSL not found, running mkcert -install...');
          final result = await BackgroundProcess.runElevated(
            elevatedCmd.executable,
            elevatedCmd.arguments,
          );

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
          wroteToSystemStore = true;
        }
      } else {
        AppLogger.info(
          'Root CA install was declined earlier; not asking again',
        );
      }

      final isInstalledNow = await checkStatus();
      if (isInstalledNow) {
        final settingsNotifier = ref.read(settingsProvider.notifier);
        await settingsNotifier.updateField(isSslInstalled: true);
        await generateSiteCert('localhost');
        AppLogger.info('SSL Root CA successfully installed and trusted');
        // The user approved one privileged command; the second one gets its
        // own prompt rather than riding along on the first approval.
        await _ensureCertutil(askPermission: askPermission);
      } else if (wroteToSystemStore) {
        AppLogger.error(
          'mkcert -install succeeded but checkStatus() still returns false',
        );
      } else if (userInitOutput.contains('certutil')) {
        AppLogger.warning(
          'certutil is not available. To trust CA in Firefox/Chrome, '
          'run: ${certutilInstallHint()}',
        );
      }
      state = AsyncValue.data(isInstalledNow);
    } catch (e) {
      AppLogger.error('Failed to initialize Root CA: $e');
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  SslInstallPrompt _rootCaPrompt(String executable, List<String> arguments) {
    return SslInstallPrompt(
      command: _describeCommand(executable, arguments),
      title: 'Trust Ponta\'s certificate?',
      message:
          'Ponta uses a local certificate authority so your .test sites load '
          'over HTTPS. Installing it adds that authority to the system trust '
          'store, which needs administrator rights. It affects every '
          'application on this machine until you uninstall it from Settings.',
    );
  }

  /// Installs the `certutil` package provider when it is missing, after asking.
  ///
  /// mkcert needs `certutil` to add the CA to the Firefox and Chrome (NSS)
  /// stores. Without it the CA is trusted system-wide but not in those
  /// browsers, so sites still show a certificate warning there. This is
  /// best-effort: a failure leaves the site certificates working, just not
  /// trusted inside those browsers.
  Future<void> _ensureCertutil({
    required Future<bool> Function(SslInstallPrompt prompt)? askPermission,
  }) async {
    if (!Platform.isLinux || askPermission == null) return;
    await ensureCertutil(
      askPermission: askPermission,
      declines: _declines,
      certutilAvailable: await isCertutilAvailable(),
      package: nssToolsPackageManager(),
      runElevated: BackgroundProcess.runElevated,
    );
  }

  /// The decision and the install behind [_ensureCertutil], with every outside
  /// dependency passed in so the flow can be tested without touching the real
  /// package manager or the user's decline file.
  @visibleForTesting
  static Future<void> ensureCertutil({
    required Future<bool> Function(SslInstallPrompt prompt) askPermission,
    required SslInstallDeclines declines,
    required bool certutilAvailable,
    required ({String packageManager, String packageName})? package,
    required Future<ProcessResult> Function(
      String executable,
      List<String> arguments,
    )
    runElevated,
  }) async {
    if (certutilAvailable) return;

    if (await declines.isDeclined(SslInstallDeclines.nssTools)) {
      AppLogger.info('certutil install was declined earlier; not asking again');
      return;
    }

    if (package == null) {
      // The app cannot install on this family, so tell the user what to run
      // instead of running a command that would fail.
      AppLogger.warning(
        'certutil is not available. To trust CA in Firefox/Chrome, '
        'run: ${certutilInstallHint()}',
      );
      return;
    }

    final refreshArgs = packageRefreshArgs(package.packageManager);
    final installArgs = packageInstallArgs(
      package.packageManager,
      package.packageName,
    );
    final prompt = SslInstallPrompt(
      title: 'Install certificate support?',
      message:
          'Firefox and Chrome need the "${package.packageName}" package to '
          'trust Ponta\'s certificate. Without it those browsers will warn '
          'about every local site. This installs the package system-wide.',
      command: _describeCommand(package.packageManager, installArgs),
    );

    final allowed = await askPermission(prompt);
    if (!allowed) {
      await declines.decline(SslInstallDeclines.nssTools);
      AppLogger.info('User declined installing ${package.packageName}');
      return;
    }

    if (refreshArgs.isNotEmpty) {
      final refresh = await runElevated(package.packageManager, refreshArgs);
      AppLogger.info(
        '${package.packageManager} refresh exit code: ${refresh.exitCode}',
      );
    }
    final install = await runElevated(package.packageManager, installArgs);
    AppLogger.info(
      '${package.packageManager} install ${package.packageName} exit code: '
      '${install.exitCode}',
    );
    if (install.exitCode != 0) {
      AppLogger.warning(
        'Could not install ${package.packageName}: ${install.stderr}',
      );
    }
  }

  Future<void> uninstallRootCA() async {
    try {
      if (!File(_mkcertPath).existsSync()) return;

      AppLogger.info('Uninstalling SSL Root CA...');

      final userCaroot = await _resolveCaroot();
      final username =
          Platform.environment['USER'] ?? Platform.environment['LOGNAME'] ?? '';

      final elevatedCmd = buildElevatedMkcertArgs(
        mkcertPath: _mkcertPath,
        carootPath: userCaroot,
        action: '-uninstall',
        username: username,
      );

      final result = await BackgroundProcess.runElevated(
        elevatedCmd.executable,
        elevatedCmd.arguments,
      );

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

      if (Platform.isLinux) {
        // Also uninstall from user browser stores
        try {
          await BackgroundProcess.run(_mkcertPath, const ['-uninstall']);
        } catch (_) {}
      }

      await ref
          .read(settingsProvider.notifier)
          .updateField(isSslInstalled: false);
      state = const AsyncValue.data(false);
      AppLogger.info('SSL Root CA successfully uninstalled');
    } catch (e) {
      AppLogger.error('Failed to uninstall Root CA: $e');
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
}

/// A privileged step waiting on the user's approval: what it does, why, and
/// the exact command that will run.
@immutable
class SslInstallPrompt {
  const SslInstallPrompt({
    required this.title,
    required this.message,
    required this.command,
  });

  final String title;
  final String message;
  final String command;
}
