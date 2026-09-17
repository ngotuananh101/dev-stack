import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dev_stack/core/services/linux_desktop_service.dart';
import 'package:path/path.dart' as p;

void main() {
  group('LinuxDesktopService', () {
    test('generateDesktopEntryContent produces valid XDG desktop file', () {
      const execPath = '/home/user/Applications/dev-stack-linux-x64.AppImage';
      final content = LinuxDesktopService.generateDesktopEntryContent(
        execPath: execPath,
      );

      expect(content, contains('[Desktop Entry]'));
      expect(content, contains('Type=Application'));
      expect(content, contains('Name=Ponta DevStack'));
      expect(content, contains('Comment=Local development stack for Web & Databases'));
      expect(content, contains('Exec="/home/user/Applications/dev-stack-linux-x64.AppImage" %u'));
      expect(content, contains('Icon=com.ponta.dev_stack'));
      expect(content, contains('Terminal=false'));
      expect(content, contains('Categories=Development;'));
      expect(content, contains('StartupWMClass=com.ponta.dev_stack'));
    });

    test('ensureDesktopIntegration creates applications dir and desktop file', () async {
      final tempDir = Directory.systemTemp.createTempSync('xdg_data_test_');
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      const fakeAppImagePath = '/opt/ponta/dev-stack.AppImage';
      await LinuxDesktopService.ensureDesktopIntegration(
        customExecPath: fakeAppImagePath,
        customXdgDataHome: tempDir,
      );

      final desktopFile = File(
        p.join(tempDir.path, 'applications', 'com.ponta.dev_stack.desktop'),
      );
      expect(desktopFile.existsSync(), isTrue);

      final content = desktopFile.readAsStringSync();
      expect(content, contains('Exec="$fakeAppImagePath" %u'));
      expect(content, contains('StartupWMClass=com.ponta.dev_stack'));
      expect(content, contains('Name=Ponta DevStack'));
    });

    test('resolveIconPath returns a valid path without crashing', () {
      final iconPath = LinuxDesktopService.resolveIconPath();
      expect(iconPath, isNotEmpty);
    });
  });
}
