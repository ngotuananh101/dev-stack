import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../config/app_config.dart';

part 'log_service.g.dart';

// ignore: non_constant_identifier_names
final AppLogger = LogService();

@riverpod
LogService logService(LogServiceRef ref) {
  return AppLogger;
}

class LogService {
  static String get baseLogDir => AppConfig.logsDir;

  /// Max size of a single daily log file before it is rotated (truncated) in
  /// place. Keeps a chatty service from growing one file to hundreds of MB
  /// across weeks, which would freeze the log viewer (readAsLines loads the
  /// whole file) and waste disk.
  static const int maxLogFileBytes = 5 * 1024 * 1024; // 5 MB

  /// Daily log files older than this are pruned on write.
  static const int retentionDays = 30;

  // Serialize writes to prevent concurrent file corruption
  Future<void>? _pendingWrite;

  /// Returns the dates (from [dates]) whose age relative to [today] is greater
  /// than [retentionDays] days. Pure and injectable so the prune decision can
  /// be tested without touching the clock.
  @visibleForTesting
  static List<DateTime> logsOlderThan(
    List<DateTime> dates, {
    required DateTime today,
    int retentionDays = LogService.retentionDays,
  }) {
    final cutoff = today.subtract(Duration(days: retentionDays));
    return dates.where((d) => d.isBefore(cutoff)).toList();
  }

  Future<void> info(String message) => _write('INFO', message);
  Future<void> error(String message) => _write('ERROR', message);
  Future<void> warning(String message) => _write('WARN', message);

  Future<void> _write(String level, String message) async {
    // Chain writes sequentially
    final completer = _pendingWrite;
    _pendingWrite = _doWrite(level, message, completer);
    await _pendingWrite;
  }

  Future<void> _doWrite(
    String level,
    String message,
    Future<void>? previous,
  ) async {
    try {
      await previous;
    } catch (_) {}

    final now = DateTime.now();
    final fileName = '${DateFormat('yyyy-MM-dd').format(now)}.log';
    final logDir = Directory(baseLogDir);

    if (!logDir.existsSync()) {
      logDir.createSync(recursive: true);
    }

    final logFile = File(p.join(baseLogDir, fileName));
    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
    final logEntry = '[$timestamp] [$level] $message\n';

    // Rotate in place if the file has grown past the cap: truncate rather
    // than append so a runaway log can't balloon without bound.
    try {
      if (logFile.existsSync() && logFile.lengthSync() > maxLogFileBytes) {
        await logFile.writeAsString('', mode: FileMode.write);
      }
    } catch (_) {
      // If we can't stat/truncate, just keep appending — better a large log
      // than a dropped line.
    }

    await logFile.writeAsString(logEntry, mode: FileMode.append);

    // Best-effort prune of stale daily files. Throttled implicitly by the
    // serialized write chain so it doesn't run on every single line.
    await _pruneOldLogs(now);

    // Also print to console for dev
    debugPrint(logEntry.trim());
  }

  Future<void> _pruneOldLogs(DateTime now) async {
    try {
      final logDir = Directory(baseLogDir);
      if (!logDir.existsSync()) return;
      final stale = <DateTime>[];
      for (final entry in logDir.listSync()) {
        if (entry is! File) continue;
        final name = p.basenameWithoutExtension(entry.path);
        DateTime? date;
        try {
          date = DateFormat('yyyy-MM-dd').parseStrict(name);
        } catch (_) {
          date = null;
        }
        if (date != null) stale.add(date);
      }
      final toDelete = logsOlderThan(stale, today: now);
      for (final date in toDelete) {
        final f = File(
          p.join(baseLogDir, '${DateFormat('yyyy-MM-dd').format(date)}.log'),
        );
        if (f.existsSync()) await f.delete();
      }
    } catch (_) {
      // Pruning is best-effort; never let it break logging.
    }
  }

  Future<List<String>> getLogsForDate(DateTime date) async {
    final fileName = '${DateFormat('yyyy-MM-dd').format(date)}.log';
    final logFile = File(p.join(baseLogDir, fileName));

    if (logFile.existsSync()) {
      return await logFile.readAsLines();
    }
    return [];
  }
}
