import 'package:dev_stack/features/cron/domain/cron_job.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults are sensible for a new job', () {
    final job = CronJob(name: 'Backup', schedule: '@daily', command: 'echo hi');
    expect(job.id, 0);
    expect(job.enabled, isTrue);
    expect(job.workingDir, '');
    expect(job.lastRunAt, isNull);
    expect(job.lastStatus, isNull);
    expect(job.lastExitCode, isNull);
  });

  test('carries all fields through', () {
    final job = CronJob(
      id: 7,
      name: 'Cleanup',
      schedule: '*/5 * * * *',
      command: 'rm -rf tmp',
      workingDir: '/tmp',
      enabled: false,
      lastStatus: 'success',
      lastExitCode: 0,
    );
    expect(job.id, 7);
    expect(job.name, 'Cleanup');
    expect(job.schedule, '*/5 * * * *');
    expect(job.command, 'rm -rf tmp');
    expect(job.workingDir, '/tmp');
    expect(job.enabled, isFalse);
    expect(job.lastStatus, 'success');
    expect(job.lastExitCode, 0);
  });
}
