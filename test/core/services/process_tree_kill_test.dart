import 'dart:io';

import 'package:dev_stack/core/services/process_tree_kill.dart';
import 'package:flutter_test/flutter_test.dart';

/// The direct children of [pid], as the OS reports them.
List<int> _childrenOf(int pid) {
  final result = Process.runSync('ps', ['-o', 'pid=', '--ppid', '$pid']);
  if (result.exitCode != 0) return const [];
  return result.stdout
      .toString()
      .split('\n')
      .map((l) => int.tryParse(l.trim()))
      .whereType<int>()
      .toList();
}

bool _alive(int pid) {
  final result = Process.runSync('kill', ['-0', '$pid']);
  return result.exitCode == 0;
}

void main() {
  test('kills the whole tree, not just the leader', () async {
    // A leader with two children: killing only the leader orphans them.
    final leader = await Process.start('/bin/sh', [
      '-c',
      'sleep 300 & sleep 300 & wait',
    ]);
    addTearDown(() {
      for (final pid in [leader.pid, ..._childrenOf(leader.pid)]) {
        try {
          Process.killPid(pid, ProcessSignal.sigkill);
        } catch (_) {}
      }
    });

    await Future<void>.delayed(const Duration(milliseconds: 300));
    final children = _childrenOf(leader.pid);
    expect(children.length, 2, reason: 'the shell must have two children');

    await killProcessTree(leader.pid);
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(_alive(leader.pid), isFalse, reason: 'the leader must be dead');
    for (final child in children) {
      expect(
        _alive(child),
        isFalse,
        reason: 'child $child must be dead too, not orphaned',
      );
    }
  });

  test('leaves a sibling that shares the caller process group alone', () async {
    // The caller and the sibling live in the same process group; a tree kill
    // must never signal that group.
    final sibling = await Process.start('/bin/sh', ['-c', 'sleep 300']);
    addTearDown(() {
      try {
        Process.killPid(sibling.pid, ProcessSignal.sigkill);
      } catch (_) {}
    });

    final leader = await Process.start('/bin/sh', ['-c', 'sleep 300 & wait']);
    addTearDown(() {
      try {
        Process.killPid(leader.pid, ProcessSignal.sigkill);
      } catch (_) {}
    });

    await Future<void>.delayed(const Duration(milliseconds: 300));
    await killProcessTree(leader.pid);
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(
      _alive(sibling.pid),
      isTrue,
      reason: 'a sibling in the caller\'s group must survive',
    );
  });

  test('is a no-op for a pid that is already gone', () async {
    // Must not throw: the process may have exited on its own.
    await expectLater(killProcessTree(999999), completes);
  });

  test('reads the process table once, not once per node', () async {
    // A 3-level chain plus a sibling: a recursive `ps --ppid` walk would run
    // one scan per node plus one for the group id, all before the first await.
    const table = '''
  10   1  10
  20  10  20
  30  20  30
  40  30  40
  11   1  11
''';
    final calls = <List<String>>[];
    await killProcessTree(
      10,
      runProcess: (executable, arguments) async {
        calls.add([executable, ...arguments]);
        if (executable == 'ps') {
          return ProcessResult(0, 0, table, '');
        }
        return ProcessResult(0, 0, '', '');
      },
    );

    final psCalls = calls.where((call) => call.first == 'ps').toList();
    expect(psCalls, hasLength(1), reason: 'one snapshot, not one per node');
    expect(psCalls.single, contains('-e'));

    final killed = calls
        .where((call) => call.first == 'kill')
        .map((call) => call.last)
        .toList();
    for (final pid in ['20', '30', '40']) {
      expect(
        killed,
        contains(pid),
        reason: 'descendant $pid must be signalled',
      );
    }
    expect(
      killed,
      isNot(contains('11')),
      reason: 'siblings are not descendants',
    );
  });

  test('parses ps rows and walks the tree in memory', () {
    final table = parseProcessTable('''
  10   1  10
  20  10  20
  30  20  20
  junk
  40  30  40
''');
    expect(table, hasLength(4));
    expect(
      descendantsIn(10, table),
      unorderedEquals([20, 30, 40]),
      reason: 'every level below the root, once',
    );
    expect(processGroupIdIn(20, table), 20);
    expect(processGroupIdIn(30, table), 20);
    expect(processGroupIdIn(99, table), isNull);
  });
}
