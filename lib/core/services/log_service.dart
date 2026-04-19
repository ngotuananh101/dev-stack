import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'log_service.g.dart';

@riverpod
LogService logService(Ref ref) {
  return LogService();
}

class LogService {
  static const String baseLogDir = 'C:\\Ponta\\logs';

  Future<void> info(String message) => _write('INFO', message);
  Future<void> error(String message) => _write('ERROR', message);
  Future<void> warning(String message) => _write('WARN', message);

  Future<void> _write(String level, String message) async {
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
