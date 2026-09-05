import 'dart:io';
import 'package:dev_stack/core/services/background_process.dart';
import 'package:dev_stack/core/services/log_service.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class HostsRepository {
  @visibleForTesting
  static String resolveHostsPath({required bool isLinux}) =>
      isLinux ? '/etc/hosts' : r'C:\Windows\System32\drivers\etc\hosts';

  static String get hostsPath => resolveHostsPath(isLinux: Platform.isLinux);

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

  Future<bool> saveHostsRaw(
    String content, {
    bool? isLinux,
    bool skipDirectWrite = false,
    Future<ProcessResult> Function(String, List<String>)? runProcess,
  }) async {
    final onLinux = isLinux ?? Platform.isLinux;
    final targetPath = resolveHostsPath(isLinux: onLinux);

    // 1. Try writing directly (if app is admin)
    if (!skipDirectWrite) {
      try {
        final file = File(targetPath);
        await file.writeAsString(content);
        return true;
      } catch (e) {
        AppLogger.error('Direct write failed, trying elevation... $e');
      }
    }

    // 2. Elevate only the copy operation.
    Directory? tempDir;
    try {
      tempDir = await Directory.systemTemp.createTemp('ponta_hosts_');
      final tempFile = File(p.join(tempDir.path, 'hosts'));
      await tempFile.writeAsString(content);

      if (onLinux) {
        // Tighten permissions on temporary file to 0600 before elevated copy (VULN-07)
        final runner = runProcess ?? Process.run;
        try {
          final chmodResult = await runner('chmod', ['600', tempFile.path]);
          if (chmodResult.exitCode != 0) {
            AppLogger.warning(
              'chmod 600 returned code ${chmodResult.exitCode}: ${chmodResult.stderr}',
            );
          }
        } catch (e) {
          AppLogger.warning('Could not set permissions 0600 on temp hosts file: $e');
        }

        final result = await BackgroundProcess.runElevated(
          'cp',
          [tempFile.path, targetPath],
          isLinux: true,
          runProcess: runner,
        );

        if (result.exitCode == 0) {
          return true;
        }
        AppLogger.error('Elevated hosts write failed: ${result.stderr}');
      } else {
        final escapedTempPath = tempFile.path.replaceAll("'", "''");
        final escapedHostsPath = targetPath.replaceAll("'", "''");
        final result = await BackgroundProcess.runElevatedPowerShell(
          "Copy-Item -LiteralPath '$escapedTempPath' "
          "-Destination '$escapedHostsPath' -Force",
        );

        if (result.exitCode == 0) {
          return true;
        }
        AppLogger.error('Elevated hosts write failed: ${result.stderr}');
      }
    } catch (e) {
      AppLogger.error('Elevation failed: $e');
    } finally {
      if (tempDir != null && tempDir.existsSync()) {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      }
    }

    return false;
  }

  Future<bool> checkAdmin() async {
    try {
      if (Platform.isLinux) {
        final result = await Process.run('id', ['-u']);
        return result.exitCode == 0 && result.stdout.toString().trim() == '0';
      }
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

