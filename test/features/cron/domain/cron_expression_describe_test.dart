// test/features/cron/domain/cron_expression_describe_test.dart
import 'package:dev_stack/features/cron/domain/cron_expression.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CronExpression.describe', () {
    test('every minute', () {
      expect(CronExpression.parse('* * * * *').describe(), 'Every minute');
    });

    test('every N minutes', () {
      expect(CronExpression.parse('*/5 * * * *').describe(),
          'Every 5 minutes');
    });

    test('at a specific time', () {
      expect(CronExpression.parse('30 8 * * *').describe(), 'At 08:30');
    });

    test('hourly', () {
      expect(CronExpression.parse('@hourly').describe(), 'Every hour');
    });

    test('daily', () {
      expect(CronExpression.parse('@daily').describe(), 'At 00:00');
    });

    test('weekly names the weekday', () {
      expect(CronExpression.parse('@weekly').describe(), 'At 00:00 on Sunday');
    });

    test('monthly', () {
      expect(CronExpression.parse('@monthly').describe(),
          'At 00:00 on day 1');
    });

    test('yearly', () {
      expect(CronExpression.parse('@yearly').describe(),
          'At 00:00 on Jan 1');
    });

    test('weekday range', () {
      expect(CronExpression.parse('0 9 * * 1-5').describe(),
          'At 09:00 on Mon-Fri');
    });
  });
}