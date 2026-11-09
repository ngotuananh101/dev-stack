import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// The result of a bounded tail read of a log file.
@immutable
class LogTail {
  const LogTail({
    required this.lines,
    required this.truncated,
    required this.bytes,
  });

  /// The last lines of the file, oldest first.
  final List<String> lines;

  /// True when older content was dropped, either because the file is larger
  /// than the byte budget or because more lines were present than requested.
  final bool truncated;

  /// Number of bytes read from disk (never the whole file when it is large).
  final int bytes;

  static const LogTail empty = LogTail(lines: [], truncated: false, bytes: 0);
}

/// Default budgets for the log viewer: a screenful-of-history tail, not the
/// whole file. A 5 MB daily log has ~40k lines, and reading it all was the
/// other half of the "first open freezes" problem.
const int kLogTailMaxBytes = 1024 * 1024; // 1 MB
const int kLogTailMaxLines = 4000;

/// Reads at most [maxBytes] from the end of [file] and returns the last
/// [maxLines] lines.
///
/// Reading the tail is O(budget) instead of O(file): `File.readAsLines()` on a
/// multi-megabyte log decodes and allocates every line before the viewer can
/// draw its first frame. The partial first line produced by seeking into the
/// middle of the file is discarded so no row is ever a half-line.
///
/// Missing files and unreadable files yield [LogTail.empty] rather than
/// throwing: a log viewer should show "no logs", not an error dialog.
Future<LogTail> readLogTail(
  File file, {
  int maxBytes = kLogTailMaxBytes,
  int maxLines = kLogTailMaxLines,
}) async {
  if (maxBytes <= 0 || maxLines <= 0) return LogTail.empty;

  RandomAccessFile? handle;
  try {
    if (!await file.exists()) return LogTail.empty;
    handle = await file.open();
    final length = await handle.length();
    if (length == 0) return LogTail.empty;

    final start = length > maxBytes ? length - maxBytes : 0;
    await handle.setPosition(start);
    final bytes = await handle.read(length - start);
    final text = utf8.decode(bytes, allowMalformed: true);

    // Seeking into the middle of the file leaves a partial first line; drop it
    // when we know content was skipped.
    var body = text;
    var truncated = start > 0;
    if (truncated) {
      final newline = body.indexOf('\n');
      body = newline == -1 ? '' : body.substring(newline + 1);
    }

    var lines = const LineSplitter().convert(body);
    if (lines.isNotEmpty && lines.last.isEmpty) {
      lines = lines.sublist(0, lines.length - 1);
    }
    if (lines.length > maxLines) {
      lines = lines.sublist(lines.length - maxLines);
      truncated = true;
    }
    return LogTail(lines: lines, truncated: truncated, bytes: bytes.length);
  } catch (_) {
    return LogTail.empty;
  } finally {
    try {
      await handle?.close();
    } catch (_) {}
  }
}
