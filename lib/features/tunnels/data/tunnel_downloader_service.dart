import 'dart:io';
import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../../core/config/app_config.dart';

final tunnelDownloaderServiceProvider = Provider<TunnelDownloaderService>((ref) {
  return TunnelDownloaderService();
});

class TunnelDownloaderService {
  final String Function() _baseDirResolver;
  final bool Function() _isWindowsResolver;
  final Dio _dio;

  TunnelDownloaderService({
    String Function()? baseDirResolver,
    bool Function()? isWindowsResolver,
    Dio? dio,
  })  : _baseDirResolver = baseDirResolver ?? (() => AppConfig.baseDir),
        _isWindowsResolver = isWindowsResolver ?? (() => Platform.isWindows),
        _dio = dio ?? Dio();

  String get tunnelsDir => p.join(_baseDirResolver(), 'bin', 'tunnels');

  String getBinaryPath(String provider) {
    final isWin = _isWindowsResolver();
    switch (provider.toLowerCase()) {
      case 'cloudflare':
        return p.join(tunnelsDir, isWin ? 'cloudflared.exe' : 'cloudflared');
      case 'ngrok':
        return p.join(tunnelsDir, isWin ? 'ngrok.exe' : 'ngrok');
      default:
        throw ArgumentError('Unsupported tunnel provider: $provider');
    }
  }

  Future<bool> isBinaryDownloaded(String provider) async {
    final file = File(getBinaryPath(provider));
    if (!await file.exists()) return false;
    final length = await file.length();
    return length > 0;
  }

  String getDownloadUrl(String provider) {
    final isWin = _isWindowsResolver();
    switch (provider.toLowerCase()) {
      case 'cloudflare':
        return isWin
            ? 'https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe'
            : 'https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64';
      case 'ngrok':
        return isWin
            ? 'https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-windows-amd64.zip'
            : 'https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz';
      default:
        throw ArgumentError('Unsupported tunnel provider: $provider');
    }
  }

  Future<void> downloadBinary(
    String provider, {
    void Function(double progress)? onProgress,
    Dio? dio,
  }) async {
    final client = dio ?? _dio;
    final targetPath = getBinaryPath(provider);
    final targetDir = Directory(tunnelsDir);
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final url = getDownloadUrl(provider);
    final isArchive = url.endsWith('.zip') || url.endsWith('.tgz');
    final tempPath = p.join(tunnelsDir, '$provider.download');

    try {
      await client.download(
        url,
        tempPath,
        onReceiveProgress: (received, total) {
          if (total > 0 && onProgress != null) {
            onProgress(received / total);
          }
        },
      );

      final downloadedFile = File(tempPath);

      if (!isArchive) {
        // Direct executable (e.g. cloudflared)
        final targetFile = File(targetPath);
        if (await targetFile.exists()) {
          await targetFile.delete();
        }
        await downloadedFile.rename(targetPath);
      } else {
        // Archive (e.g. ngrok .zip or .tgz)
        final bytes = await downloadedFile.readAsBytes();
        Archive archive;
        if (url.endsWith('.zip')) {
          archive = ZipDecoder().decodeBytes(bytes);
        } else {
          final decompressed = GZipDecoder().decodeBytes(bytes);
          archive = TarDecoder().decodeBytes(decompressed);
        }

        final binName = _isWindowsResolver() ? 'ngrok.exe' : 'ngrok';
        ArchiveFile? binFile;
        for (final file in archive) {
          if (p.basename(file.name) == binName) {
            binFile = file;
            break;
          }
        }

        if (binFile == null) {
          throw StateError('Binary $binName not found inside archive from $url');
        }

        final targetFile = File(targetPath);
        await targetFile.writeAsBytes(binFile.content as List<int>);
        if (await downloadedFile.exists()) {
          await downloadedFile.delete();
        }
      }

      // Ensure executable permissions on Linux
      if (!_isWindowsResolver()) {
        await Process.run('chmod', ['+x', targetPath]);
      }
    } catch (e) {
      final tempFile = File(tempPath);
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      rethrow;
    }
  }
}
