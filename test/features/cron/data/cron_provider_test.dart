import 'package:dev_stack/features/cron/data/cron_provider.dart';
import 'package:dev_stack/features/cron/domain/cron_job.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a job without an id is recognized as new', () {
    final j = CronJob(name: 'a', schedule: '@daily', command: 'echo');
    expect(CronJobsRepository.isNew(j), isTrue);
  });

  test('a job with an id is recognized as existing', () {
    final j = CronJob(id: 5, name: 'a', schedule: '@daily', command: 'echo');
    expect(CronJobsRepository.isNew(j), isFalse);
  });

  test('the run-state provider is exposed as a NotifierProvider', () {
    expect(cronRunStateProvider, isA<NotifierProvider<dynamic, dynamic>>());
  });
}
