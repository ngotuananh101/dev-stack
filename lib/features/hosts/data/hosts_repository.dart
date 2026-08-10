import 'dart:io';
import 'package:dev_stack/core/services/background_process.dart';
import 'package:dev_stack/core/services/log_service.dart';

class HostsRepository {
  static const String hostsPath = r'C:\Windows\System32\drivers\etc\hosts';

  Future<String> readHostsRaw() async {
    try {
      final file = File(hostsPath);
      if (!await file.exists()) return '';
      // Use system encoding to handle non-ASCII comments/hostnames
      final bytes = await file.readAsBytes();
      try {
        return systemEncoding.decode(bytes);
      } catch (_) {
        return String.fromCharCodes(bytes);
      }
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

    // 2. Elevate only the copy operation. The PowerShell host itself runs
    // hidden; Windows may still show the required UAC consent dialog.
    try {
      final tempFile = File('${Directory.systemTemp.path}\\hosts_temp');
      await tempFile.writeAsString(content);

      final escapedTempPath = tempFile.path.replaceAll("'", "''");
      final escapedHostsPath = hostsPath.replaceAll("'", "''");
      final result = await BackgroundProcess.runElevatedPowerShell(
        "Copy-Item -LiteralPath '$escapedTempPath' "
        "-Destination '$escapedHostsPath' -Force",
      );

      if (result.exitCode == 0) {
        return true;
      }
      AppLogger.error('Elevated hosts write failed: ${result.stderr}');
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

  /// Replaces (or appends) the PONTA-managed block in a hosts file.
  ///
  /// The block is delimited by [startMarker]..[endMarker] in document order.
  /// Using an ordered regex instead of indexOf avoids a RangeError when the
  /// markers are out of order (e.g. a user moved end above start) and avoids
  /// adopting a stale block when a duplicate marker is present.
  static String replacePontaBlock(
    String hostsContent,
    String startMarker,
    String endMarker,
    List<String> domainLines,
  ) {
    final newBlock = '$startMarker\n${domainLines.join('\n')}\n$endMarker';

    final blockPattern = RegExp(
      '${RegExp.escape(startMarker)}.*?${RegExp.escape(endMarker)}',
      dotAll: true,
    );

    if (blockPattern.hasMatch(hostsContent)) {
      return hostsContent.replaceFirst(blockPattern, newBlock);
    }
    return '${hostsContent.trim()}\n\n$newBlock\n';
  }
}
