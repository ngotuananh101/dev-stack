import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../config/app_config.dart';

part 'log_service.g.dart';

// ignore: non_constant_identifier_names
final AppLogger = LogService();

@riverpod
LogService logService(Ref ref) {
  return AppLogger;
}

class LogService {
  static String get baseLogDir => AppConfig.logsDir;
  
  // Serialize writes to prevent concurrent file corruption
  Future<void>? _pendingWrite;

  Future<void> info(String message) => _write('INFO', message);
  Future<void> error(String message) => _write('ERROR', message);
  Future<void> warning(String message) => _write('WARN', message);

  Future<void> _write(String level, String message) async {
    // Chain writes sequentially
    final completer = _pendingWrite;
    _pendingWrite = _doWrite(level, message, completer);
    await _pendingWrite;
  }

  Future<void> _doWrite(String level, String message, Future<void>? previous) async {
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

    await logFile.writeAsString(logEntry, mode: FileMode.append);
    
    // Also print to console for dev
    debugPrint(logEntry.trim());
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
