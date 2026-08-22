import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dev_stack/core/services/background_process.dart';

class _FakeProcess implements Process {
  @override
  final int pid;
  bool killed = false;
  ProcessSignal? lastSignal;

  _FakeProcess(this.pid);

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed = true;
    lastSignal = signal;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('BackgroundProcess command formatting', () {
    test('builds Linux elevated command arguments correctly', () {
      final cmd = BackgroundProcess.buildLinuxElevatedArgs('cp', ['/tmp/a', '/etc/hosts']);
      expect(cmd.executable, equals('pkexec'));
      expect(cmd.arguments, equals(['cp', '/tmp/a', '/etc/hosts']));
    });

    test('builds Linux kill command arguments with negative PID for process group', () {
      final cmd = BackgroundProcess.buildLinuxKillArgs(12345);
      expect(cmd.executable, equals('kill'));
      expect(cmd.arguments, equals(['-TERM', '--', '-12345']));
    });
  });

  group('BackgroundProcess.stopManaged (non-Windows)', () {
    test('attempts group kill via negative PID when runProcess succeeds', () async {
      final fake = _FakeProcess(4321);
      final managed = ManagedBackgroundProcess.wrap(fake);

      String? calledExecutable;
      List<String>? calledArgs;

      await BackgroundProcess.stopManaged(
        managed,
        isWindows: false,
        runProcess: (exec, args) async {
          calledExecutable = exec;
          calledArgs = args;
          return ProcessResult(999, 0, '', '');
        },
      );

      expect(calledExecutable, equals('kill'));
      expect(calledArgs, equals(['-TERM', '--', '-4321']));
      expect(fake.killed, isFalse);
    });

    test('falls back to process.kill when group kill command fails with non-zero exitCode', () async {
      final fake = _FakeProcess(4321);
      final managed = ManagedBackgroundProcess.wrap(fake);

      await BackgroundProcess.stopManaged(
        managed,
        isWindows: false,
        runProcess: (exec, args) async {
          return ProcessResult(999, 1, '', 'No such process');
        },
      );

      expect(fake.killed, isTrue);
      expect(fake.lastSignal, equals(ProcessSignal.sigterm));
    });

    test('falls back to process.kill when group kill throws an exception', () async {
      final fake = _FakeProcess(4321);
      final managed = ManagedBackgroundProcess.wrap(fake);

      await BackgroundProcess.stopManaged(
        managed,
        isWindows: false,
        runProcess: (exec, args) async {
          throw const ProcessException('kill', ['-TERM', '--', '-4321'], 'Command not found');
        },
      );

      expect(fake.killed, isTrue);
      expect(fake.lastSignal, equals(ProcessSignal.sigterm));
    });
  });
}
