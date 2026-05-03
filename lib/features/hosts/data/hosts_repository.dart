import 'dart:io';
import 'package:dev_stack/core/services/log_service.dart';

class HostsRepository {
  static const String hostsPath = r'C:\Windows\System32\drivers\etc\hosts';

  Future<String> readHostsRaw() async {
    try {
      final file = File(hostsPath);
      if (!await file.exists()) return '';
      return await file.readAsString();
    } catch (e) {
      AppLogger.error('Error reading hosts raw: $e');
      return '';
    }
  }

  Future<bool> saveHostsRaw(String content) async {
    // 1. Try writing directly (if app is admin)
    try {
      final file = File(hostsPath);
      await file.writeAsString(content);
      return true;
    } catch (e) {
      AppLogger.error('Direct write failed, trying elevation... $e');
    }

    // 2. Try elevation via PowerShell
    try {
      final tempFile = File('${Directory.systemTemp.path}\\hosts_temp');
      await tempFile.writeAsString(content);

      // PowerShell command to copy temp to system hosts using RunAs
      final result = await Process.run('powershell', [
        '-Command',
        'Start-Process powershell -ArgumentList \'-Command "Copy-Item -Path \'\'${tempFile.path}\'\' -Destination \'\'$hostsPath\'\' -Force"\' -Verb RunAs -Wait'
      ]);

      if (result.exitCode == 0) {
        return true;
      }
    } catch (e) {
      AppLogger.error('Elevation failed: $e');
    }

    return false;
  }

  Future<bool> checkAdmin() async {
    try {
      final result = await Process.run('net', ['session']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}
