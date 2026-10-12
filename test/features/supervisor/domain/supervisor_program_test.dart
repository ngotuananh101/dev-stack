import 'package:dev_stack/features/supervisor/domain/supervisor_program.dart';
import 'package:dev_stack/features/supervisor/domain/supervisor_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults keep a program supervised and restartable', () {
    final p = SupervisorProgram(name: 'Queue', command: 'php artisan queue:work');
    expect(p.id, 0);
    expect(p.autoStart, isFalse);
    expect(p.autoRestart, isTrue);
    expect(p.maxRestarts, 5);
    expect(p.restartWindowSeconds, 60);
    expect(p.restartDelaySeconds, 2);
    expect(p.enabled, isTrue);
    expect(p.environmentJson, '{}');
    expect(p.envVars(), isEmpty);
  });

  test('envVars decodes the JSON blob', () {
    final p = SupervisorProgram(
      name: 'Worker',
      command: 'node worker.js',
      environmentJson: '{"QUEUE":"high","DEBUG":"1"}',
    );
    expect(p.envVars(), {'QUEUE': 'high', 'DEBUG': '1'});
  });

  test('envVars tolerates malformed JSON', () {
    final p = SupervisorProgram(
      name: 'Bad',
      command: 'x',
      environmentJson: 'not json',
    );
    expect(p.envVars(), isEmpty);
  });

  test('status enum has the expected members', () {
    expect(SupervisorStatus.values, [
      SupervisorStatus.stopped,
      SupervisorStatus.starting,
      SupervisorStatus.running,
      SupervisorStatus.stopping,
      SupervisorStatus.restarting,
      SupervisorStatus.fatal,
    ]);
  });
}
