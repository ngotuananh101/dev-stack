import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../../../core/services/background_process.dart';
import '../../../core/services/log_service.dart';
import '../../../core/database/isar_provider.dart';
import '../domain/tunnel_model.dart';
import '../domain/tunnel_session.dart';
import '../domain/tunnel_driver.dart';
import '../../../features/settings/domain/app_settings.dart';
import 'drivers/cloudflare_driver.dart';
import 'drivers/ngrok_driver.dart';
import 'tunnel_downloader_service.dart';

typedef ProcessStarter = Future<dynamic> Function(String executable, List<String> arguments);
typedef ProcessStopper = Future<void> Function(int pid);

@visibleForTesting
class FakeManagedProcess {
  final int pid;
  final StreamController<List<int>> stdoutController = StreamController<List<int>>.broadcast();
  final StreamController<List<int>> stderrController = StreamController<List<int>>.broadcast();

  FakeManagedProcess(this.pid);

  Stream<List<int>> get stdout => stdoutController.stream;
  Stream<List<int>> get stderr => stderrController.stream;
}

final tunnelManagerServiceProvider = Provider<TunnelManagerService>((ref) {
  final downloader = ref.read(tunnelDownloaderServiceProvider);
  final logger = ref.read(logServiceProvider);
  final isarAsync = ref.read(isarProvider);
  final isar = isarAsync.value;

  final manager = TunnelManagerService(
    downloader: downloader,
    logger: logger,
    isar: isar,
  );

  ref.onDispose(() => unawaited(manager.dispose()));
  return manager;
});

class TunnelManagerService {
  final TunnelDownloaderService _downloader;
  final LogService? _logger;
  final Isar? _isar;
  final Map<String, TunnelDriver> _drivers;
  final ProcessStarter _startProcess;
  late final ProcessStopper _stopProcess;

  final Map<int, TunnelSession> _sessions = {};
  final Map<int, dynamic> _activeProcesses = {};
  final Map<int, List<StreamSubscription>> _logSubscriptions = {};
  final StreamController<Map<int, TunnelSession>> _sessionsController =
      StreamController<Map<int, TunnelSession>>.broadcast();

  TunnelManagerService({
    TunnelDownloaderService? downloader,
    LogService? logger,
    Isar? isar,
    Map<String, TunnelDriver>? drivers,
    ProcessStarter? startProcessFn,
    ProcessStopper? stopProcessFn,
  })  : _downloader = downloader ?? TunnelDownloaderService(),
        _logger = logger,
        _isar = isar,
        _drivers = drivers ?? {
          'cloudflare': CloudflareDriver(),
          'ngrok': NgrokDriver(),
        },
        _startProcess = startProcessFn ??
            ((exec, args) => BackgroundProcess.start(exec, args)) {
    _stopProcess = stopProcessFn ?? _defaultStopProcess;
  }

  Future<void> _defaultStopProcess(int pid) async {
    for (final proc in List.of(_activeProcesses.values)) {
      if (proc is ManagedBackgroundProcess) {
        final childPid = await proc.childPid;
        if (childPid == pid || proc.pid == pid) {
          await BackgroundProcess.stopManaged(proc);
        }
      }
    }
  }

  Stream<Map<int, TunnelSession>> get sessionsStream => _sessionsController.stream;

  Map<int, TunnelSession> get currentSessions => Map.unmodifiable(_sessions);

  TunnelSession? getSession(int tunnelId) => _sessions[tunnelId];

  void _updateSession(int tunnelId, TunnelSession session) {
    _sessions[tunnelId] = session;
    _sessionsController.add(Map.unmodifiable(_sessions));
  }

  Future<void> startTunnel(TunnelModel tunnel, {String? defaultToken}) async {
    final driver = _drivers[tunnel.provider.toLowerCase()];
    if (driver == null) {
      throw ArgumentError('Unsupported driver: ${tunnel.provider}');
    }

    // Resolve default token from settings if not provided and tunnel has none.
    String? resolvedDefaultToken = defaultToken;
    final isar = _isar;
    if (tunnel.authToken == null || tunnel.authToken!.trim().isEmpty) {
      if (resolvedDefaultToken == null && isar != null) {
        final settings = await isar.appSettings.where().findFirst();
        if (tunnel.provider.toLowerCase() == 'ngrok') {
          resolvedDefaultToken = settings?.ngrokDefaultToken;
        } else if (tunnel.provider.toLowerCase() == 'cloudflare') {
          resolvedDefaultToken = settings?.cloudflareDefaultToken;
        }
      }
    }

    tunnel.lastActiveAt = DateTime.now();
    await saveTunnel(tunnel);

    _updateSession(
      tunnel.id,
      TunnelSession(
        tunnelId: tunnel.id,
        status: TunnelStatus.downloadingBinary,
      ),
    );

    try {
      final ready = await _downloader.isBinaryDownloaded(tunnel.provider);
      if (!ready) {
        await _downloader.downloadBinary(
          tunnel.provider,
          onProgress: (progress) {
            final current = _sessions[tunnel.id];
            if (current != null) {
              _updateSession(
                tunnel.id,
                current.copyWith(downloadProgress: progress),
              );
            }
          },
        );
      }

      final execPath = _downloader.getBinaryPath(tunnel.provider);
      final args = driver.buildStartArguments(
        tunnel,
        defaultToken: resolvedDefaultToken,
      );

      _updateSession(
        tunnel.id,
        TunnelSession(
          tunnelId: tunnel.id,
          status: TunnelStatus.connecting,
        ),
      );

      final process = await _startProcess(execPath, args);

      int pid;
      if (process is ManagedBackgroundProcess) {
        pid = await process.childPid;
      } else if (process is FakeManagedProcess) {
        pid = process.pid;
      } else {
        throw StateError('Unknown process type: ${process.runtimeType}');
      }

      _activeProcesses[tunnel.id] = process;

      final initialSession = TunnelSession(
        tunnelId: tunnel.id,
        status: TunnelStatus.connecting,
        pid: pid,
        connectedAt: DateTime.now(),
      );
      _updateSession(tunnel.id, initialSession);

      final subscriptions = <StreamSubscription>[];

      void handleLine(String line) {
        final current = _sessions[tunnel.id] ?? initialSession;
        var updatedLogs = [...current.logs, line];
        if (updatedLogs.length > 500) {
          updatedLogs = updatedLogs.sublist(updatedLogs.length - 500);
        }

        var next = current.copyWith(logs: updatedLogs);

        final publicUrl = driver.parsePublicUrl(line);
        if (publicUrl != null) {
          next = next.copyWith(
            status: TunnelStatus.running,
            publicUrl: publicUrl,
          );
        }

        final inspectorUrl = driver.parseInspectorUrl(line);
        if (inspectorUrl != null) {
          next = next.copyWith(webInspectorUrl: inspectorUrl);
        }

        _updateSession(tunnel.id, next);
      }

      void cleanupProcess() {
        _cleanupLogSubscriptions(tunnel.id);
        final session = _sessions[tunnel.id];
        if (session != null &&
            session.status != TunnelStatus.stopped &&
            session.status != TunnelStatus.error) {
          _updateSession(
            tunnel.id,
            session.copyWith(status: TunnelStatus.stopped),
          );
        }
      }

      if (process is ManagedBackgroundProcess) {
        subscriptions.add(
          process.stdout
              .transform(utf8.decoder)
              .transform(const LineSplitter())
              .listen(handleLine),
        );
        subscriptions.add(
          process.stderr
              .transform(utf8.decoder)
              .transform(const LineSplitter())
              .listen(handleLine),
        );
        process.exitCode.then((_) => cleanupProcess(), onError: (_) => cleanupProcess());
      } else if (process is FakeManagedProcess) {
        subscriptions.add(
          process.stdout
              .transform(utf8.decoder)
              .transform(const LineSplitter())
              .listen(handleLine, onError: (_) => cleanupProcess(), onDone: cleanupProcess),
        );
        subscriptions.add(
          process.stderr
              .transform(utf8.decoder)
              .transform(const LineSplitter())
              .listen(handleLine, onError: (_) => cleanupProcess(), onDone: cleanupProcess),
        );
      }

      _logSubscriptions[tunnel.id] = subscriptions;
    } catch (e, st) {
      _logger?.error('Failed to start tunnel ${tunnel.id}: $e\n$st');
      _updateSession(
        tunnel.id,
        TunnelSession(
          tunnelId: tunnel.id,
          status: TunnelStatus.error,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> stopTunnel(int tunnelId) async {
    _cleanupLogSubscriptions(tunnelId);

    final session = _sessions[tunnelId];
    final pid = session?.pid;

    if (pid != null) {
      try {
        await _stopProcess(pid);
      } catch (e) {
        _logger?.error('Error stopping tunnel process $pid: $e');
      }
    }

    _activeProcesses.remove(tunnelId);
    _updateSession(
      tunnelId,
      TunnelSession(
        tunnelId: tunnelId,
        status: TunnelStatus.stopped,
      ),
    );
  }

  Future<TunnelModel> saveTunnel(TunnelModel tunnel) async {
    final isar = _isar;
    if (isar != null) {
      await isar.writeTxn(() async {
        await isar.tunnelModels.put(tunnel);
      });
    }
    return tunnel;
  }

  Future<void> deleteTunnel(int id) async {
    await stopTunnel(id);
    final isar = _isar;
    if (isar != null) {
      await isar.writeTxn(() async {
        await isar.tunnelModels.delete(id);
      });
    }
    _sessions.remove(id);
    _sessionsController.add(Map.unmodifiable(_sessions));
  }

  void _cleanupLogSubscriptions(int tunnelId) {
    final subs = _logSubscriptions.remove(tunnelId);
    if (subs != null) {
      for (final sub in subs) {
        sub.cancel();
      }
    }
  }

  Future<void> dispose() async {
    for (final entry in _activeProcesses.entries) {
      final session = _sessions[entry.key];
      final pid = session?.pid;
      if (pid != null) {
        try {
          await _stopProcess(pid);
        } catch (_) {}
      }
    }
    _activeProcesses.clear();

    for (final subs in _logSubscriptions.values) {
      for (final sub in subs) {
        sub.cancel();
      }
    }
    _logSubscriptions.clear();

    _sessions.clear();
    await _sessionsController.close();
  }
}
