import 'dart:io';

import 'package:dev_stack/features/apps/data/linux_php_extension_driver.dart';
import 'package:dev_stack/features/apps/data/linux_php_extension_manager.dart';
import 'package:dev_stack/features/apps/data/linux_php_introspector.dart';
import 'package:dev_stack/features/apps/data/php_extension_drivers/debian_php_extension_driver.dart';
import 'package:dev_stack/features/apps/data/php_settings_provider.dart';
import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:dev_stack/features/apps/domain/php_extension.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sentinel so `_linuxPhpApp(execFilePath: null)` really means "no binary",
/// rather than falling back to the default.
const Object _unset = Object();

AppModel _linuxPhpApp({
  Object? execFilePath = _unset,
  String appId = 'php85',
  String? installedVersion = '8.5.0',
}) => AppModel(
  appId: appId,
  name: 'PHP 8.5',
  categories: ['runtime'],
  groupName: 'php',
  versions: ['8.5.0'],
  location: 'system_package',
  isInstalled: true,
  installedVersion: installedVersion,
  execFilePath: identical(execFilePath, _unset)
      ? '/usr/sbin/php-fpm8.5'
      : execFilePath as String?,
)..servicePid = 4242;

void main() {
  group('PhpSettings Linux branch', () {
    test('getLinuxExtensions returns the manager list for a known family', () async {
      final settings = PhpSettings();
      final manager = _FakeManager(
        extensions: [
          PhpExtension(
            name: 'curl',
            fileName: 'curl.so',
            isEnabled: true,
            isFoundInIni: true,
            isZend: false,
            isInstalled: true,
            packageName: 'php8.5-curl',
            description: 'CURL module for PHP',
          ),
        ],
      );

      final exts = await settings.getLinuxExtensions(
        _linuxPhpApp(),
        familyOverride: 'ubuntu',
        managerOverride: manager,
      );

      expect(exts.length, equals(1));
      expect(manager.capturedVersion, equals('8.5'));
      expect(
        manager.capturedBinary,
        equals('/usr/sbin/php-fpm8.5'),
      );
    });

    test('getLinuxExtensions throws UnsupportedError for an unknown family', () async {
      final settings = PhpSettings();

      expect(
        () => settings.getLinuxExtensions(
          _linuxPhpApp(),
          familyOverride: 'unknown',
        ),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('getLinuxExtensions throws StateError when no binary is recorded', () async {
      final settings = PhpSettings();

      expect(
        () => settings.getLinuxExtensions(
          _linuxPhpApp(execFilePath: null),
          familyOverride: 'ubuntu',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('toggleLinuxExtension forwards scanDir, ini list and servicePid', () async {
      final settings = PhpSettings();
      final manager = _FakeManager(extensions: const []);
      final app = _linuxPhpApp();

      final message = await settings.toggleLinuxExtension(
        app,
        PhpExtension(
          name: 'curl',
          fileName: 'curl.so',
          isEnabled: false,
          isFoundInIni: true,
          isZend: false,
          isInstalled: true,
          packageName: 'php8.5-curl',
        ),
        true,
        familyOverride: 'debian',
        managerOverride: manager,
        infoOverride: (
          scanDir: '/etc/php/8.5/fpm/conf.d',
          parsedIniFiles: ['/etc/php/8.5/fpm/conf.d/20-curl.ini'],
        ),
      );

      expect(manager.toggledName, equals('curl'));
      expect(manager.toggledEnable, isTrue);
      expect(manager.toggledPid, equals(4242));
      expect(manager.toggledScanDir, equals('/etc/php/8.5/fpm/conf.d'));
      expect(
        manager.toggledIniFiles,
        equals(['/etc/php/8.5/fpm/conf.d/20-curl.ini']),
      );
      // The manager's message is handed straight back to the caller, which is
      // what Task 10 renders in a snackbar.
      expect(message, equals('ok'));
    });

    test('toggleLinuxExtension throws UnsupportedError for an unknown family', () async {
      final settings = PhpSettings();
      final app = _linuxPhpApp();

      expect(
        () => settings.toggleLinuxExtension(
          app,
          PhpExtension(
            name: 'curl',
            fileName: 'curl.so',
            isEnabled: false,
            isFoundInIni: true,
            isZend: false,
          ),
          true,
          familyOverride: 'nixos',
        ),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('falls back to installedVersion when the appId is not phpNN', () async {
      final settings = PhpSettings();
      final manager = _FakeManager(extensions: const []);

      await settings.getLinuxExtensions(
        _linuxPhpApp(appId: 'php'),
        familyOverride: 'ubuntu',
        managerOverride: manager,
      );

      expect(manager.capturedVersion, equals('8.5'));
    });

    test('throws StateError when no version can be determined', () async {
      final settings = PhpSettings();

      expect(
        () => settings.getLinuxExtensions(
          _linuxPhpApp(appId: 'php', installedVersion: 'latest'),
          familyOverride: 'ubuntu',
          managerOverride: _FakeManager(extensions: const []),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('throws StateError when php-fpm reports no scan dir', () async {
      final settings = PhpSettings();
      final app = _linuxPhpApp();

      expect(
        () => settings.toggleLinuxExtension(
          app,
          PhpExtension(
            name: 'curl',
            fileName: 'curl.so',
            isEnabled: false,
            isFoundInIni: true,
            isZend: false,
          ),
          true,
          familyOverride: 'debian',
          managerOverride: _FakeManager(extensions: const []),
          infoOverride: (scanDir: null, parsedIniFiles: const []),
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}

/// Minimal fake standing in for LinuxPhpExtensionManager. It subclasses the
/// real manager with a Debian driver so no constructor signature can drift
/// unnoticed; only the two methods the provider calls are overridden.
class _FakeManager extends LinuxPhpExtensionManager {
  final List<PhpExtension> extensions;
  String? capturedBinary;
  String? capturedVersion;
  String? toggledName;
  bool? toggledEnable;
  int? toggledPid;
  String? toggledScanDir;
  List<String>? toggledIniFiles;

  _FakeManager({required this.extensions})
    : super(
        introspector: LinuxPhpIntrospector(runProcess: _noRun),
        driver: DebianPhpExtensionDriver(),
        runProcess: _noRun,
      );

  static Future<ProcessResult> _noRun(String exe, List<String> args) async =>
      ProcessResult(0, 0, '', '');

  @override
  Future<List<PhpExtension>> listExtensions({
    required String binaryPath,
    required String phpVersion,
  }) async {
    capturedBinary = binaryPath;
    capturedVersion = phpVersion;
    return extensions;
  }

  @override
  Future<String> applyToggle({
    required String binaryPath,
    required String phpVersion,
    required String scanDir,
    required List<String> parsedIniFiles,
    required String extName,
    required bool enable,
    int? servicePid,
  }) async {
    toggledName = extName;
    toggledEnable = enable;
    toggledPid = servicePid;
    toggledScanDir = scanDir;
    toggledIniFiles = parsedIniFiles;
    return 'ok';
  }
}
