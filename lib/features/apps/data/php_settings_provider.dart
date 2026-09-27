import 'dart:io';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/services/background_process.dart';
import '../../../core/services/linux_distro_resolver.dart';
import '../domain/app_model.dart';
import '../domain/php_extension.dart';
import 'app_installer_service.dart';
import 'linux_php_extension_driver.dart';
import 'linux_php_extension_manager.dart';
import 'linux_php_introspector.dart';
export '../domain/php_extension.dart';

part 'php_settings_provider.g.dart';

/// Resolves the php.ini configuration file path for an app.
///
/// On Windows or for custom directory locations, points to `<location>/php.ini`.
/// On Linux with `system_package`, checks known system locations in priority order:
/// 1. `/etc/php/<version>/fpm/php.ini` (Debian/Ubuntu PHP-FPM)
/// 2. `/etc/php/<version>/cli/php.ini` (Debian/Ubuntu PHP CLI)
/// 3. `/etc/php.ini` (RHEL/CentOS/Fedora)
/// 4. `/etc/php.d/<version>.ini`
/// 5. `/etc/opt/remi/php<versionRaw>/php.ini`
///
/// If none exist, falls back to `/etc/php/<version>/fpm/php.ini`.
String? resolvePhpIniPath(
  AppModel app, {
  bool? isLinux,
  bool Function(String path)? fileExists,
}) {
  if (app.location == null || app.location!.isEmpty) {
    return null;
  }

  final onLinux = isLinux ?? Platform.isLinux;
  if (!onLinux || app.location != 'system_package') {
    final pathContext = onLinux ? p.posix : p.context;
    return pathContext.join(app.location!, 'php.ini');
  }

  final checkFile = fileExists ?? ((path) => File(path).existsSync());
  final version = _extractPhpVersion(app);
  final versionRaw = version?.replaceAll('.', '');

  final candidates = <String>[
    if (version != null) '/etc/php/$version/fpm/php.ini',
    if (version != null) '/etc/php/$version/cli/php.ini',
    if (versionRaw != null) '/etc/opt/remi/php$versionRaw/php.ini',
    if (version != null) '/etc/php.d/$version.ini',
    '/etc/php.ini',
  ];

  for (final candidate in candidates) {
    if (checkFile(candidate)) {
      return candidate;
    }
  }

  if (version != null) {
    return '/etc/php/$version/fpm/php.ini';
  }
  return '/etc/php.ini';
}

/// Resolves the php.ini [File] for an app using [resolvePhpIniPath].
File? resolvePhpIniFile(
  AppModel app, {
  bool? isLinux,
  bool Function(String path)? fileExists,
}) {
  final path = resolvePhpIniPath(app, isLinux: isLinux, fileExists: fileExists);
  if (path == null) return null;
  return File(path);
}

String? _extractPhpVersion(AppModel app) {
  final match = RegExp(r'[\d.]+').firstMatch(app.appId);
  if (match != null && match.group(0)!.isNotEmpty) {
    final raw = match.group(0)!;
    if (raw.contains('.')) {
      final parts = raw.split('.').where((segment) => segment.isNotEmpty).toList();
      if (parts.length >= 2) {
        return '${parts[0]}.${parts[1]}';
      }
      return parts.isNotEmpty ? parts[0] : null;
    }
    if (raw.length == 2) {
      return '${raw[0]}.${raw[1]}';
    }
    if (raw.length > 2) {
      return '${raw[0]}.${raw[1]}';
    }
    return raw;
  }
  if (app.installedVersion != null && app.installedVersion!.isNotEmpty) {
    final matchInv = RegExp(r'[\d.]+').firstMatch(app.installedVersion!);
    if (matchInv != null && matchInv.group(0)!.isNotEmpty) {
      final raw = matchInv.group(0)!;
      final parts = raw.split('.').where((segment) => segment.isNotEmpty).toList();
      if (parts.length >= 2) {
        return '${parts[0]}.${parts[1]}';
      }
      return parts.isNotEmpty ? parts[0] : null;
    }
  }
  return null;
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

  Future<List<PhpExtension>> getExtensions(AppModel app, [String? iniContent]) async {
    if (Platform.isLinux && app.location == AppInstallerService.systemPackageMarker) {
      return getLinuxExtensions(app);
    }
    if (app.location == null) return [];
    
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
      caseSensitive: false
    );

    final matches = extLineRegex.allMatches(content);
    for (final match in matches) {
      final fullLine = match.group(0)!;
      String name = match.group(1)!.toLowerCase();

      // If it's an absolute path, extract the filename
      if (name.contains('\\') || name.contains('/')) {
        name = name.split(RegExp(r'[\\/]')).last;
        // Clean up php_ prefix and extension suffix if present in filename
        name = name.replaceAll('.dll', '').replaceAll('.so', '').replaceFirst('php_', '');
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

      bool isZend = lowerName == 'xdebug'; // opcache is usually internal or also zend
      bool isEnabled = activeExtensions.contains(lowerName);
      bool isFoundInIni = isEnabled || disabledExtensions.contains(lowerName);
      
      extensions.add(PhpExtension(
        name: name,
        fileName: fileName,
        isEnabled: isEnabled,
        isFoundInIni: isFoundInIni,
        isZend: isZend,
      ));
    }

    // Sort: Enabled first, then by name
    extensions.sort((a, b) {
      if (a.isEnabled != b.isEnabled) return a.isEnabled ? -1 : 1;
      return a.name.compareTo(b.name);
    });

    return extensions;
  }

  Future<String?> toggleExtension(AppModel app, PhpExtension ext, bool enable) async {
    if (Platform.isLinux && app.location == AppInstallerService.systemPackageMarker) {
      return toggleLinuxExtension(app, ext, enable);
    }

    final file = _getPhpIni(app);
    if (file == null || !await file.exists() || app.location == null) return null;

    String content = await file.readAsString();
    final name = ext.name;
    
    // 1. Remove ALL existing lines for this extension (enabled or commented)
    // This cleans up any previous attempts or manual edits to avoid duplication
    // Handles both short names and absolute paths
    final searchRegex = RegExp(
      r'^;?\s*(?:extension|zend_extension)\s*=\s*"?\s*(?:[^"\r\n]*?[\\/])?(?:php_)?' + RegExp.escape(name) + r'(?:\.dll)?"?\s*$\r?\n?', 
      multiLine: true, 
      caseSensitive: false
    );
    content = content.replaceAll(searchRegex, '');

    if (enable) {
      final type = ext.isZend ? 'zend_extension' : 'extension';
      final extPath = '${app.location}${Platform.pathSeparator}ext${Platform.pathSeparator}${ext.fileName}';
      final newLine = '$type="$extPath"';
      
      // 2. Try to insert after opcache for organization, else append
      final opcacheRegex = RegExp(r'^;?\s*zend_extension\s*=\s*"?\s*opcache(?:\.dll)?"?\s*$', multiLine: true, caseSensitive: false);
      
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
    final manager = managerOverride ?? LinuxPhpExtensionManager.forApp(
      app: app,
      driver: driver,
    );
    final phpVersion = _linuxPhpVersion(app);   // e.g. 'php85' -> '8.5'
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

    final manager = managerOverride ?? LinuxPhpExtensionManager.forApp(
      app: app,
      driver: driver,
    );
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
