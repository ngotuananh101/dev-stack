import 'dart:io';

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
Future<void> killProcessTree(int pid) async {
  if (Platform.isWindows) {
    await _run('taskkill', ['/F', '/T', '/PID', '$pid']);
    return;
  }

  final descendants = _descendantsOf(pid);
  final leadsOwnGroup = _processGroupId(pid) == pid;

  if (leadsOwnGroup) {
    await _run('kill', ['-TERM', '--', '-$pid']);
  }
  for (final child in descendants) {
    await _run('kill', ['-TERM', '$child']);
  }

  await Future<void>.delayed(const Duration(milliseconds: 300));

  if (leadsOwnGroup) {
    await _run('kill', ['-9', '--', '-$pid']);
  }
  for (final child in descendants) {
    await _run('kill', ['-9', '$child']);
  }
  // Direct fallback in case the group signal missed (e.g. the child is no
  // longer a process-group leader).
  await _run('kill', ['-9', '$pid']);
}

/// The pids of every descendant of [pid], parents before their children.
List<int> _descendantsOf(int pid) {
  final result = Process.runSync('ps', ['-o', 'pid=', '--ppid', '$pid']);
  if (result.exitCode != 0) return const [];
  final children = result.stdout
      .toString()
      .split('\n')
      .map((line) => int.tryParse(line.trim()))
      .whereType<int>()
      .toList();
  return [
    for (final child in children) ...[
      child,
      ..._descendantsOf(child),
    ],
  ];
}

/// The process-group id of [pid], or `null` when the process is gone.
int? _processGroupId(int pid) {
  final result = Process.runSync('ps', ['-o', 'pgid=', '-p', '$pid']);
  if (result.exitCode != 0) return null;
  return int.tryParse(result.stdout.toString().trim());
}

/// Runs a command, swallowing failures: a process that is already gone makes
/// every kill fail, and that is not an error worth propagating.
Future<void> _run(String executable, List<String> arguments) async {
  try {
    await Process.run(executable, arguments);
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

  final descendants = _descendantsOf(pid);
  final leadsOwnGroup = _processGroupId(pid) == pid;

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

/// Runs a command synchronously, swallowing failures.
void _runSync(String executable, List<String> arguments) {
  try {
    Process.runSync(executable, arguments);
  } catch (_) {
    // Best-effort.
  }
}
