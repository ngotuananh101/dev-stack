import 'dart:io';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/services/background_process.dart';
import '../../../core/services/linux_distro_resolver.dart';
import '../domain/app_model.dart';
import '../domain/php_extension.dart';
import 'php_runtime_bundle.dart';
import 'app_installer_service.dart';
import 'linux_php_extension_driver.dart';
import 'linux_php_extension_manager.dart';
import 'linux_php_introspector.dart';
export '../domain/php_extension.dart';

part 'php_settings_provider.g.dart';

/// Resolves the php.ini configuration file path for an app.
///
/// Returns [PhpRuntimeBundle.pathFor('php_ini')] on Linux when a bundle
/// is present, otherwise `<location>/php.ini`.
String? resolvePhpIniPath(AppModel app, {bool? isLinux}) {
  final location = app.location;
  if (location == null || location.isEmpty) return null;
  final onLinux = isLinux ?? Platform.isLinux;
  if (onLinux) {
    final bundle = PhpRuntimeBundle.load(location);
    if (bundle != null) return bundle.pathFor('php_ini');
  }
  return (onLinux ? p.posix : p.context).join(location, 'php.ini');
}

/// Resolves the php.ini [File] for an app using [resolvePhpIniPath].
File? resolvePhpIniFile(
  AppModel app, {
  bool? isLinux,
}) {
  final path = resolvePhpIniPath(app, isLinux: isLinux);
  if (path == null) return null;
  return File(path);
}

@riverpod
class PhpSettings extends _$PhpSettings {
  @override
  void build() {}

  File? _getPhpIni(AppModel app) {
    return resolvePhpIniFile(app);
  }

  Future<String> readPhpIni(AppModel app) async {
    final file = _getPhpIni(app);
    if (file == null || !await file.exists()) return '';
    return await file.readAsString();
  }

  Future<void> savePhpIni(AppModel app, String content) async {
    final file = _getPhpIni(app);
    if (file == null) return;
    await BackgroundProcess.writeStringElevated(file.path, content);
  }

  Future<List<PhpExtension>> getExtensions(
    AppModel app, [
    String? iniContent,
  ]) async {
    if (Platform.isLinux &&
        app.location == 'system_package') {
      return getLinuxExtensions(app);
    }
    if (app.location == null) return [];
    final bundle = Platform.isLinux
        ? PhpRuntimeBundle.load(app.location!)
        : null;
    if (bundle != null) {
      final content = iniContent ?? await readPhpIni(app);
      final common = _activeBundleModules(content);
      final active = {...common};
      for (final file in Directory(
        bundle.pathFor('fpm_scan_dir'),
      ).listSync().whereType<File>()) {
        if (file.path.endsWith('.ini')) {
          active.addAll(_activeBundleModules(await file.readAsString()));
        }
      }
      final extensions = bundle.sharedModules
          .map(
            (module) => PhpExtension(
              name: module.name,
              fileName: p.basename(module.path),
              isEnabled: active.contains(module.name),
              isFoundInIni: active.contains(module.name),
              isZend: module.directive == 'zend_extension',
            ),
          )
          .toList();
      extensions.sort(
        (a, b) => a.isEnabled == b.isEnabled
            ? a.name.compareTo(b.name)
            : (a.isEnabled ? -1 : 1),
      );
      return extensions;
    }

    final extDir = Directory('${app.location}${Platform.pathSeparator}ext');
    if (!await extDir.exists()) return [];

    final content = iniContent ?? await readPhpIni(app);
    final List<FileSystemEntity> entities = await extDir.list().toList();
    // Scan for both .dll (Windows) and .so (Linux) extension files
    final extFiles = entities.where((f) {
      final lower = f.path.toLowerCase();
      return lower.endsWith('.dll') || lower.endsWith('.so');
    }).toList();

    // Optimize: Parse ini once to find all extension lines
    final activeExtensions = <String>{};
    final disabledExtensions = <String>{};

    // Regex to match extension/zend_extension lines and capture the name
    // Matches: extension=mbstring, ;extension=curl, zend_extension="opcache"
    // Also matches .dll and .so extensions
    final extLineRegex = RegExp(
      r'^;?\s*(?:extension|zend_extension)\s*=\s*"?\s*(?:php_)?([^"\r\n]+?)(?:\.d?ll|\.so)?"?\s*$',
      multiLine: true,
      caseSensitive: false,
    );

    final matches = extLineRegex.allMatches(content);
    for (final match in matches) {
      final fullLine = match.group(0)!;
      String name = match.group(1)!.toLowerCase();

      // If it's an absolute path, extract the filename
      if (name.contains('\\') || name.contains('/')) {
        name = name.split(RegExp(r'[\\/]')).last;
        // Clean up php_ prefix and extension suffix if present in filename
        name = name
            .replaceAll('.dll', '')
            .replaceAll('.so', '')
            .replaceFirst('php_', '');
      }

      if (fullLine.trim().startsWith(';')) {
        disabledExtensions.add(name);
      } else {
        activeExtensions.add(name);
      }
    }

    final List<PhpExtension> extensions = [];

    for (final file in extFiles) {
      final fileName = file.path.split(Platform.pathSeparator).last;

      // Strip both .dll and .so extensions
      String name = fileName.replaceAll('.dll', '').replaceAll('.so', '');
      if (name.startsWith('php_')) {
        name = name.substring(4);
      }
      final lowerName = name.toLowerCase();

      // Skip opcache and xdebug as requested
      if (lowerName == 'opcache' || lowerName == 'xdebug') continue;

      bool isZend =
          lowerName == 'xdebug'; // opcache is usually internal or also zend
      bool isEnabled = activeExtensions.contains(lowerName);
      bool isFoundInIni = isEnabled || disabledExtensions.contains(lowerName);

      extensions.add(
        PhpExtension(
          name: name,
          fileName: fileName,
          isEnabled: isEnabled,
          isFoundInIni: isFoundInIni,
          isZend: isZend,
        ),
      );
    }

    // Sort: Enabled first, then by name
    extensions.sort((a, b) {
      if (a.isEnabled != b.isEnabled) return a.isEnabled ? -1 : 1;
      return a.name.compareTo(b.name);
    });

    return extensions;
  }

  Future<String?> toggleExtension(
    AppModel app,
    PhpExtension ext,
    bool enable, {
    Future<ProcessResult> Function(String, List<String>)? runProcess,
  }) async {
    if (Platform.isLinux &&
        app.location == 'system_package') {
      return toggleLinuxExtension(app, ext, enable);
    }

    final bundle = Platform.isLinux && app.location != null
        ? PhpRuntimeBundle.load(app.location!)
        : null;
    if (bundle != null) {
      final module = bundle.sharedModules
          .where((m) => m.name == ext.name)
          .firstOrNull;
      if (module == null) {
        throw StateError(
          'Extension ${ext.name} is not in the PHP bundle registry.',
        );
      }
      final common = await File(bundle.pathFor('php_ini')).readAsString();
      if (_activeBundleModules(common).contains(module.name)) {
        throw StateError(
          'Remove the ${module.name} directive from php.ini before using the extension toggle.',
        );
      }
      if (enable) await module.validateHash();
      final runner = runProcess ?? Process.run;
      final result = await runner(bundle.pathFor('extension_manager'), [
        enable ? 'enable' : 'disable',
        module.name,
        'all',
      ]);
      if (result.exitCode != 0) {
        throw StateError(
          'PHP extension toggle failed (${result.exitCode}): ${result.stderr}',
        );
      }
      final pid = app.servicePid;
      if (pid != null && pid > 0) {
        try {
          final reload = BackgroundProcess.buildLinuxReloadArgs(pid);
          final result = await runner(reload.executable, reload.arguments);
          if (result.exitCode == 0) return null;
        } catch (_) {
          // Toggle succeeded; a failed reload does not roll it back.
        }
      }
      return 'Extension updated. Please restart PHP-FPM to apply the change.';
    }

    final file = _getPhpIni(app);
    if (file == null || !await file.exists() || app.location == null) {
      return null;
    }

    String content = await file.readAsString();
    final name = ext.name;

    // 1. Remove ALL existing lines for this extension (enabled or commented)
    // This cleans up any previous attempts or manual edits to avoid duplication
    // Handles both short names and absolute paths
    final searchRegex = RegExp(
      r'^;?\s*(?:extension|zend_extension)\s*=\s*"?\s*(?:[^"\r\n]*?[\\/])?(?:php_)?' +
          RegExp.escape(name) +
          r'(?:\.dll|\.so)?"?\s*$\r?\n?',
      multiLine: true,
      caseSensitive: false,
    );
    content = content.replaceAll(searchRegex, '');

    if (enable) {
      final type = ext.isZend ? 'zend_extension' : 'extension';
      final extPath =
          '${app.location}${Platform.pathSeparator}ext${Platform.pathSeparator}${ext.fileName}';
      final newLine = '$type="$extPath"';

      // 2. Try to insert after opcache for organization, else append
      final opcacheRegex = RegExp(
        r'^;?\s*zend_extension\s*=\s*"?\s*opcache(?:\.dll)?"?\s*$',
        multiLine: true,
        caseSensitive: false,
      );

      if (opcacheRegex.hasMatch(content)) {
        content = content.replaceFirstMapped(opcacheRegex, (match) {
          return '${match.group(0)}\n$newLine';
        });
      } else {
        content += '\n$newLine';
      }
    }

    await BackgroundProcess.writeStringElevated(file.path, content);
    return null;
  }

  Set<String> _activeBundleModules(String content) {
    final modules = <String>{};
    final directive = RegExp(
      r'''^\s*(?:extension|zend_extension)\s*=\s*(?:"([^"]+)"|'([^']+)'|([^;\r\n]+))\s*(?:;.*)?$''',
      multiLine: true,
      caseSensitive: false,
    );
    for (final match in directive.allMatches(content)) {
      final value = (match.group(1) ?? match.group(2) ?? match.group(3)!)
          .trim();
      final name = value
          .split(RegExp(r'[\\/]'))
          .last
          .toLowerCase()
          .replaceFirst(RegExp(r'\.(?:dll|so)$'), '')
          .replaceFirst(RegExp(r'^php_'), '');
      modules.add(name);
    }
    return modules;
  }

  @visibleForTesting
  Future<List<PhpExtension>> getLinuxExtensions(
    AppModel app, {
    String? familyOverride,
    LinuxPhpExtensionManager? managerOverride,
  }) async {
    final family = familyOverride ?? LinuxDistroResolver.detectFamily();
    final driver = driverForFamily(family);
    if (driver == null) {
      throw UnsupportedError(
        'PHP extensions are not supported on this Linux distribution ($family).',
      );
    }
    final binaryPath = app.execFilePath;
    if (binaryPath == null || binaryPath.isEmpty) {
      throw StateError('No php-fpm binary recorded for ${app.appId}.');
    }
    final manager =
        managerOverride ??
        LinuxPhpExtensionManager.forApp(app: app, driver: driver);
    final phpVersion = _linuxPhpVersion(app); // e.g. 'php85' -> '8.5'
    try {
      return await manager.listExtensions(
        binaryPath: binaryPath,
        phpVersion: phpVersion,
      );
    } on LinuxPhpDiscoveryUnavailable catch (e) {
      throw UnsupportedError(e.message);
    }
  }

  @visibleForTesting
  Future<String?> toggleLinuxExtension(
    AppModel app,
    PhpExtension ext,
    bool enable, {
    String? familyOverride,
    LinuxPhpExtensionManager? managerOverride,
    LinuxPhpIntrospector? introspectorOverride,
    ({String? scanDir, List<String> parsedIniFiles})? infoOverride,
  }) async {
    final family = familyOverride ?? LinuxDistroResolver.detectFamily();
    final driver = driverForFamily(family);
    if (driver == null) {
      throw UnsupportedError(
        'PHP extensions are not supported on this Linux distribution ($family).',
      );
    }
    final binaryPath = app.execFilePath;
    if (binaryPath == null || binaryPath.isEmpty) {
      throw StateError('No php-fpm binary recorded for ${app.appId}.');
    }
    final phpVersion = _linuxPhpVersion(app);

    String? scanDir;
    List<String> parsedIniFiles;
    if (infoOverride != null) {
      scanDir = infoOverride.scanDir;
      parsedIniFiles = infoOverride.parsedIniFiles;
    } else {
      final info = await (introspectorOverride ?? LinuxPhpIntrospector())
          .readInfo(binaryPath);
      scanDir = info.scanDir;
      parsedIniFiles = info.scannedIniFiles;
    }
    if (scanDir == null) {
      throw StateError(
        'PHP-FPM reported no scan directory for $binaryPath; '
        'there is nowhere to write the extension ini file.',
      );
    }

    final manager =
        managerOverride ??
        LinuxPhpExtensionManager.forApp(app: app, driver: driver);
    return manager.applyToggle(
      binaryPath: binaryPath,
      phpVersion: phpVersion,
      scanDir: scanDir,
      parsedIniFiles: parsedIniFiles,
      extName: ext.name,
      enable: enable,
      servicePid: app.servicePid,
    );
  }

  String _linuxPhpVersion(AppModel app) {
    final fromId = AppInstallerService.phpPrefixFor(app.appId);
    if (fromId != null) return fromId;

    final match = RegExp(r'^(\d+\.\d+)').firstMatch(app.installedVersion ?? '');
    if (match != null) return match.group(1)!;

    throw StateError(
      'Cannot determine the PHP version for ${app.appId}; '
      'extension discovery needs a major.minor version.',
    );
  }
}
