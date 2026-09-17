import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:dev_stack/core/services/log_service.dart';

class LinuxDesktopService {
  static const String appId = 'com.ponta.dev_stack';
  static const String appName = 'Ponta DevStack';
  static const String appComment =
      'Local development stack for Web & Databases';

  static String? _cachedIconPath;

  /// Returns the cached absolute icon path if available.
  static String? get cachedIconPath => _cachedIconPath;

  /// Resolves the best absolute path to icon.png for windowManager or trayManager.
  static String resolveIconPath() {
    if (_cachedIconPath != null && File(_cachedIconPath!).existsSync()) {
      return _cachedIconPath!;
    }

    final dataHome = _resolveXdgDataHome();
    if (dataHome != null) {
      final installedIcon = File(
        p.join(dataHome.path, 'icons', 'hicolor', '256x256', 'apps', '$appId.png'),
      );
      if (installedIcon.existsSync()) {
        _cachedIconPath = installedIcon.path;
        return installedIcon.path;
      }
    }

    final searchPaths = [
      p.join(
        p.dirname(Platform.resolvedExecutable),
        'data',
        'flutter_assets',
        'assets',
        'images',
        'icon.png',
      ),
      p.join(p.dirname(Platform.resolvedExecutable), 'dev_stack.png'),
      p.join(p.dirname(Platform.resolvedExecutable), 'com.ponta.dev_stack.png'),
      p.join(Directory.current.path, 'assets', 'images', 'icon.png'),
    ];

    for (final path in searchPaths) {
      if (File(path).existsSync()) {
        _cachedIconPath = path;
        return path;
      }
    }

    return 'assets/images/icon.png';
  }

  /// Returns the target .desktop file content.
  static String generateDesktopEntryContent({required String execPath}) {
    return '''[Desktop Entry]
Type=Application
Name=$appName
Comment=$appComment
Exec="$execPath" %u
Icon=$appId
Terminal=false
Categories=Development;
StartupWMClass=$appId
''';
  }

  /// Ensures that the application has a valid .desktop file and hicolor icon
  /// installed in the user's XDG data directory (~/.local/share).
  ///
  /// This ensures GNOME Shell (Wayland/X11) can resolve the app_id to the
  /// application name and icon on the top bar, dash/dock, and app switcher.
  static Future<String?> ensureDesktopIntegration({
    String? customExecPath,
    Directory? customXdgDataHome,
  }) async {
    if (!Platform.isLinux) return null;

    try {
      final dataHome = customXdgDataHome ?? _resolveXdgDataHome();
      if (dataHome == null) return null;

      final appsDir = Directory(p.join(dataHome.path, 'applications'));
      final iconsDir = Directory(
        p.join(dataHome.path, 'icons', 'hicolor', '256x256', 'apps'),
      );

      if (!appsDir.existsSync()) {
        appsDir.createSync(recursive: true);
      }
      if (!iconsDir.existsSync()) {
        iconsDir.createSync(recursive: true);
      }

      // 1. Extract and install icon
      final iconFile = File(p.join(iconsDir.path, '$appId.png'));
      await _ensureIconInstalled(iconFile);
      if (iconFile.existsSync()) {
        _cachedIconPath = iconFile.path;
      }

      // 2. Resolve target execution path (prefer APPIMAGE environment variable)
      final execPath = customExecPath ??
          Platform.environment['APPIMAGE'] ??
          Platform.resolvedExecutable;

      // 3. Create or update .desktop file
      final desktopFile = File(p.join(appsDir.path, '$appId.desktop'));
      final expectedContent = generateDesktopEntryContent(execPath: execPath);

      bool needsWrite = true;
      if (desktopFile.existsSync()) {
        try {
          final currentContent = await desktopFile.readAsString();
          if (currentContent == expectedContent) {
            needsWrite = false;
          }
        } catch (_) {
          needsWrite = true;
        }
      }

      if (needsWrite) {
        await desktopFile.writeAsString(expectedContent, flush: true);
        try {
          await Process.run('chmod', ['+x', desktopFile.path]);
        } catch (_) {}

        // Notify desktop environment if tools are available
        try {
          await Process.run('update-desktop-database', [appsDir.path]);
        } catch (_) {}
        try {
          final hicolorBase = p.join(dataHome.path, 'icons', 'hicolor');
          await Process.run('gtk-update-icon-cache', ['-q', '-t', '-f', hicolorBase]);
        } catch (_) {}
      }

      return _cachedIconPath;
    } catch (e) {
      AppLogger.warning('Linux desktop integration failed: $e');
      return null;
    }
  }

  static Directory? _resolveXdgDataHome() {
    final xdgDataHome = Platform.environment['XDG_DATA_HOME'];
    if (xdgDataHome != null && xdgDataHome.isNotEmpty) {
      return Directory(xdgDataHome);
    }
    final home = Platform.environment['HOME'];
    if (home != null && home.isNotEmpty) {
      return Directory(p.join(home, '.local', 'share'));
    }
    return null;
  }

  static Future<void> _ensureIconInstalled(File targetIcon) async {
    if (targetIcon.existsSync() && targetIcon.lengthSync() > 0) {
      return;
    }

    // Try reading from Flutter asset bundle first
    try {
      final byteData = await rootBundle.load('assets/images/icon.png');
      final bytes = byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );
      await targetIcon.writeAsBytes(bytes, flush: true);
      return;
    } catch (_) {}

    // Fallback: look for icon file relative to executable or working dir
    final searchPaths = [
      p.join(
        p.dirname(Platform.resolvedExecutable),
        'data',
        'flutter_assets',
        'assets',
        'images',
        'icon.png',
      ),
      p.join(p.dirname(Platform.resolvedExecutable), 'dev_stack.png'),
      p.join(p.dirname(Platform.resolvedExecutable), 'com.ponta.dev_stack.png'),
      'assets/images/icon.png',
    ];

    for (final path in searchPaths) {
      final file = File(path);
      if (file.existsSync() && file.lengthSync() > 0) {
        try {
          await file.copy(targetIcon.path);
          return;
        } catch (_) {}
      }
    }
  }
}
