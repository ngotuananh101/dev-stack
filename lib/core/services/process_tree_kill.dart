import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Terminates the entire process tree rooted at [pid].
///
/// A "tree" is the root plus every descendant the OS still reports. The
/// descendants are collected *before* the root is killed: once the root dies
/// its children are reparented to init and can no longer be found by walking
/// the tree.
///
/// The process group is signalled only when the root actually leads it (its
/// pid equals its pgid, which is what `setsid` gives us). Signalling a
/// negative pid that happens to be some other group's id would kill an
/// unrelated group — including the app's own — so it is never sent blind.
///
/// The process table is read with a **single** `ps` call. The earlier
/// implementation ran `Process.runSync('ps', '--ppid')` once per node, plus
/// another for the group id, before the first `await` — so a stop button
/// blocked the UI isolate for N+2 sequential subprocesses on a large tree.
Future<void> killProcessTree(
  int pid, {
  @visibleForTesting
  Future<ProcessResult> Function(String, List<String>)? runProcess,
}) async {
  if (Platform.isWindows) {
    await _run('taskkill', [
      '/F',
      '/T',
      '/PID',
      '$pid',
    ], runProcess: runProcess);
    return;
  }

  final table = await _processTable(runProcess: runProcess);
  final descendants = descendantsIn(pid, table);
  final leadsOwnGroup = processGroupIdIn(pid, table) == pid;

  if (leadsOwnGroup) {
    await _run('kill', ['-TERM', '--', '-$pid'], runProcess: runProcess);
  }
  for (final child in descendants) {
    await _run('kill', ['-TERM', '$child'], runProcess: runProcess);
  }

  await Future<void>.delayed(const Duration(milliseconds: 300));

  if (leadsOwnGroup) {
    await _run('kill', ['-9', '--', '-$pid'], runProcess: runProcess);
  }
  for (final child in descendants) {
    await _run('kill', ['-9', '$child'], runProcess: runProcess);
  }
  // Direct fallback in case the group signal missed (e.g. the child is no
  // longer a process-group leader).
  await _run('kill', ['-9', '$pid'], runProcess: runProcess);
}

/// One row of the POSIX process table.
@immutable
class ProcessTableEntry {
  final int pid;
  final int parentPid;
  final int processGroupId;

  const ProcessTableEntry({
    required this.pid,
    required this.parentPid,
    required this.processGroupId,
  });

  @override
  bool operator ==(Object other) =>
      other is ProcessTableEntry &&
      other.pid == pid &&
      other.parentPid == parentPid &&
      other.processGroupId == processGroupId;

  @override
  int get hashCode => Object.hash(pid, parentPid, processGroupId);

  @override
  String toString() =>
      'ProcessTableEntry(pid: $pid, ppid: $parentPid, pgid: $processGroupId)';
}

/// Parses `ps -e -o pid=,ppid=,pgid=` output.
///
/// Pure so the tree walk can be tested without spawning anything; malformed
/// rows are skipped rather than aborting the parse.
@visibleForTesting
List<ProcessTableEntry> parseProcessTable(String output) {
  final entries = <ProcessTableEntry>[];
  for (final line in const LineSplitter().convert(output)) {
    final fields = line.trim().split(RegExp(r'\s+'));
    if (fields.length < 3) continue;
    final pid = int.tryParse(fields[0]);
    final parentPid = int.tryParse(fields[1]);
    final processGroupId = int.tryParse(fields[2]);
    if (pid == null || parentPid == null || processGroupId == null) continue;
    entries.add(
      ProcessTableEntry(
        pid: pid,
        parentPid: parentPid,
        processGroupId: processGroupId,
      ),
    );
  }
  return entries;
}

/// The pids of every descendant of [pid], parents before their children.
///
/// Walks the already-parsed [table] in memory: one pass to index the children,
/// then a depth-first walk, instead of one process scan per node.
@visibleForTesting
List<int> descendantsIn(int pid, List<ProcessTableEntry> table) {
  final children = <int, List<int>>{};
  for (final entry in table) {
    children.putIfAbsent(entry.parentPid, () => <int>[]).add(entry.pid);
  }

  final result = <int>[];
  final stack = <int>[pid];
  final seen = <int>{pid};
  while (stack.isNotEmpty) {
    final current = stack.removeLast();
    for (final child in children[current] ?? const <int>[]) {
      if (!seen.add(child)) continue;
      result.add(child);
      stack.add(child);
    }
  }
  return result;
}

/// The process-group id of [pid] in [table], or `null` when it is not listed.
@visibleForTesting
int? processGroupIdIn(int pid, List<ProcessTableEntry> table) {
  for (final entry in table) {
    if (entry.pid == pid) return entry.processGroupId;
  }
  return null;
}

Future<List<ProcessTableEntry>> _processTable({
  Future<ProcessResult> Function(String, List<String>)? runProcess,
}) async {
  final runner = runProcess ?? Process.run;
  try {
    final result = await runner('ps', [
      '-e',
      '-o',
      'pid=',
      '-o',
      'ppid=',
      '-o',
      'pgid=',
    ]);
    if (result.exitCode != 0) return const [];
    return parseProcessTable(result.stdout.toString());
  } catch (_) {
    return const [];
  }
}

/// Runs a command, swallowing failures: a process that is already gone makes
/// every kill fail, and that is not an error worth propagating.
Future<void> _run(
  String executable,
  List<String> arguments, {
  Future<ProcessResult> Function(String, List<String>)? runProcess,
}) async {
  try {
    final runner = runProcess ?? Process.run;
    await runner(executable, arguments);
  } catch (_) {
    // Best-effort.
  }
}

/// Terminates the tree rooted at [pid] synchronously, with SIGKILL only.
///
/// Used on shutdown: the isolate may die before an awaited kill could run, so
/// the signals have to be sent before the call returns. The grace period of
/// [killProcessTree] is pointless here — the point is that nothing survives.
void killProcessTreeSync(int pid) {
  if (Platform.isWindows) {
    _runSync('taskkill', ['/F', '/T', '/PID', '$pid']);
    return;
  }

  final table = _processTableSync();
  final descendants = descendantsIn(pid, table);
  final leadsOwnGroup = processGroupIdIn(pid, table) == pid;

  // The descendants first: once the leader dies they are reparented to init
  // and can no longer be found.
  for (final child in descendants) {
    _runSync('kill', ['-9', '$child']);
  }
  if (leadsOwnGroup) {
    _runSync('kill', ['-9', '--', '-$pid']);
  }
  _runSync('kill', ['-9', '$pid']);
}

List<ProcessTableEntry> _processTableSync() {
  try {
    final result = Process.runSync('ps', [
      '-e',
      '-o',
      'pid=',
      '-o',
      'ppid=',
      '-o',
      'pgid=',
    ]);
    if (result.exitCode != 0) return const [];
    return parseProcessTable(result.stdout.toString());
  } catch (_) {
    return const [];
  }
}

/// Runs a command synchronously, swallowing failures.
void _runSync(String executable, List<String> arguments) {
  try {
    Process.runSync(executable, arguments);
  } catch (_) {
    // Best-effort.
  }
}
