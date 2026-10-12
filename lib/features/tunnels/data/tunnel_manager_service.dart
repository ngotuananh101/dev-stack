import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_plus/isar_plus.dart';
import 'package:dio/dio.dart';
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
  /// Cancel tokens for tunnels whose start is still in flight (binary download
  /// or process launch). Cancelling the token aborts the download; a tunnel
  /// whose process has already launched is torn down instead.
  final Map<int, CancelToken> _startCancelTokens = {};
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
            ((exec, args) async => ManagedBackgroundProcess.wrap(
                  await Process.start(
                    exec,
                    args,
                    mode: ProcessStartMode.normal,
                  ),
                )) {
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
        final settings = isar.appSettings.where().findFirst();
        if (tunnel.provider.toLowerCase() == 'ngrok') {
          resolvedDefaultToken = settings?.ngrokDefaultToken;
        } else if (tunnel.provider.toLowerCase() == 'cloudflare') {
          resolvedDefaultToken = settings?.cloudflareDefaultToken;
        }
      }
    }

    tunnel.lastActiveAt = DateTime.now();
    await saveTunnel(tunnel);

    // One token per in-flight start: it is cancelled by [cancelStart] to abort
    // the download, and cleared once the start settles.
    final cancelToken = CancelToken();
    _startCancelTokens[tunnel.id] = cancelToken;

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
          cancelToken: cancelToken,
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

      // A cancel may have landed between the download finishing and here (or
      // the binary was already present, so no download observed it). Bail out
      // before launching a process the user already asked to stop.
      if (cancelToken.isCancelled) {
        _updateSession(
          tunnel.id,
          TunnelSession(tunnelId: tunnel.id, status: TunnelStatus.stopped),
        );
        return;
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

      void cleanupProcess([int? exitCode]) {
        _cleanupLogSubscriptions(tunnel.id);
        final session = _sessions[tunnel.id];
        if (session != null &&
            session.status != TunnelStatus.stopped &&
            session.status != TunnelStatus.error) {
          final isAbnormal = exitCode != null && exitCode != 0;
          _updateSession(
            tunnel.id,
            session.copyWith(
              status: isAbnormal ? TunnelStatus.error : TunnelStatus.stopped,
              errorMessage: isAbnormal ? 'Process exited with code $exitCode' : null,
            ),
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
        process.exitCode.then((code) => cleanupProcess(code), onError: (_) => cleanupProcess());
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
      // A cancelled start is not a failure: the user asked for it, so settle
      // the session at "stopped" rather than surfacing a red error.
      if (cancelToken.isCancelled) {
        _updateSession(
          tunnel.id,
          TunnelSession(tunnelId: tunnel.id, status: TunnelStatus.stopped),
        );
      } else {
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
    } finally {
      _startCancelTokens.remove(tunnel.id);
    }
  }

  /// Cancels an in-flight [startTunnel] for [tunnelId].
  ///
  /// If the binary is still downloading, the cancel token aborts the request
  /// (leaving no temp file behind). If the process has already launched, it is
  /// stopped. Either way the session settles at [TunnelStatus.stopped]. A no-op
  /// when nothing is starting for [tunnelId].
  Future<void> cancelStart(int tunnelId) async {
    final token = _startCancelTokens.remove(tunnelId);
    if (token != null && !token.isCancelled) {
      token.cancel('Tunnel start cancelled by user');
    }

    final session = _sessions[tunnelId];
    if (session == null) return;

    final pid = session.pid;
    if (pid != null) {
      try {
        await _stopProcess(pid);
      } catch (e) {
        _logger?.error('Error stopping tunnel process $pid: $e');
      }
      _activeProcesses.remove(tunnelId);
      _cleanupLogSubscriptions(tunnelId);
      _updateSession(
        tunnelId,
        TunnelSession(tunnelId: tunnelId, status: TunnelStatus.stopped),
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
      isar.write((_) {
        // isar_plus: 0 is not an auto-increment sentinel. If this tunnel was
        // constructed without an id (defaulting to 0), allocate a fresh id so
        // it doesn't overwrite other tunnels.
        if (tunnel.id == 0) {
          tunnel.id = isar.tunnelModels.autoIncrement();
        }
        isar.tunnelModels.put(tunnel);
      });
    }
    return tunnel;
  }

  Future<void> deleteTunnel(int id) async {
    await stopTunnel(id);
    final isar = _isar;
    if (isar != null) {
      isar.write((_) {
        isar.tunnelModels.delete(id);
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
