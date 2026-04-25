import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'apps_provider.dart';

part 'pyenv_provider.g.dart';

@riverpod
class PyenvNotifier extends _$PyenvNotifier {
  @override
  Future<List<String>> build() async {
    return _getInstalledVersions();
  }

  Future<String?> _getPyenvPath() async {
    final apps = await ref.read(appsNotifierProvider.future);
    final pyenvApp = apps.where((a) => a.appId == 'pyenv').firstOrNull;
    return pyenvApp?.cliFilePath;
  }

  Future<List<String>> _getInstalledVersions() async {
    final pyenvPath = await _getPyenvPath();
    if (pyenvPath == null) return [];

    try {
      final result = await Process.run(pyenvPath, ['versions']);
      if (result.exitCode == 0) {
        final lines = result.stdout.toString().split('\n');
        return lines
            .map((l) => l.trim().replaceAll('*', '').trim())
            .where((l) => l.isNotEmpty && !l.contains('current'))
            .toList();
      }
    } catch (e) {
      debugPrint('Error listing pyenv versions: $e');
    }
    return [];
  }

  Future<List<String>> getInstallableVersions() async {
    final pyenvPath = await _getPyenvPath();
    if (pyenvPath == null) return [];

    try {
      final result = await Process.run(pyenvPath, ['install', '-l']);
      if (result.exitCode == 0) {
        final lines = result.stdout.toString().split('\n');
        final list = lines
            .map((l) => l.trim())
            .where(
              (l) => l.isNotEmpty && RegExp(r'^\d+\.\d+\.\d+$').hasMatch(l),
            )
            .toList();

        // Group by major.minor and keep latest patch
        final latestVersions = <String, String>{};
        for (final v in list) {
          final parts = v.split('.');
          if (parts.length >= 2) {
            final key = '${parts[0]}.${parts[1]}';
            final currentLatest = latestVersions[key];
            if (currentLatest == null) {
              latestVersions[key] = v;
            } else {
              // Compare patch versions
              final currentPatch =
                  int.tryParse(currentLatest.split('.')[2]) ?? 0;
              final newPatch = int.tryParse(parts[2]) ?? 0;
              if (newPatch > currentPatch) {
                latestVersions[key] = v;
              }
            }
          }
        }

        return latestVersions.values.toList().reversed.toList();
      }
    } catch (e) {
      debugPrint('Error listing installable versions: $e');
    }
    return [];
  }

  Future<void> installVersion(String version, {Function(String)? onLog}) async {
    final pyenvPath = await _getPyenvPath();
    if (pyenvPath == null) throw Exception('pyenv not found');

    onLog?.call('Starting installation of Python $version...');

    // Use start instead of run for real-time output if needed, but for now run is easier
    final result = await Process.run(pyenvPath, ['install', version]);
    if (result.exitCode != 0) {
      onLog?.call('Error: ${result.stderr}');
      throw Exception('Failed to install Python $version');
    }

    onLog?.call('Successfully installed Python $version');
    ref.invalidateSelf();
  }

  Future<void> uninstallVersion(String version) async {
    final pyenvPath = await _getPyenvPath();
    if (pyenvPath == null) throw Exception('pyenv not found');

    final result = await Process.run(pyenvPath, ['uninstall', '-f', version]);
    if (result.exitCode != 0) {
      throw Exception('Failed to uninstall Python $version');
    }
    ref.invalidateSelf();
  }

  Future<void> globalVersion(String version) async {
    final pyenvPath = await _getPyenvPath();
    if (pyenvPath == null) throw Exception('pyenv not found');

    final result = await Process.run(pyenvPath, ['global', version]);
    if (result.exitCode != 0) {
      throw Exception('Failed to set global Python $version');
    }
    ref.invalidateSelf();
  }

  Future<String?> getCurrentVersion() async {
    final pyenvPath = await _getPyenvPath();
    if (pyenvPath == null) return null;

    final result = await Process.run(pyenvPath, ['version']);
    if (result.exitCode == 0) {
      return result.stdout.toString().split(' ').firstOrNull;
    }
    return null;
  }
}
