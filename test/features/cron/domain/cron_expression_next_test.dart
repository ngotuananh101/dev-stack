// test/features/cron/domain/cron_expression_next_test.dart
import 'package:dev_stack/features/cron/domain/cron_expression.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DateTime at(int y, int mo, int d, int h, int mi) =>
      DateTime(y, mo, d, h, mi, 30, 123); // non-zero s/ms on purpose

  group('CronExpression.nextOccurrence', () {
    test('every minute returns the next minute', () {
      final e = CronExpression.parse('* * * * *');
      expect(e.nextOccurrence(at(2026, 10, 12, 8, 30)),
          DateTime(2026, 10, 12, 8, 31));
    });

    test('is strictly after `from` even when from is an exact match', () {
      final e = CronExpression.parse('30 8 * * *');
      expect(e.nextOccurrence(DateTime(2026, 10, 12, 8, 30)),
          DateTime(2026, 10, 13, 8, 30));
    });

    test('rolls across an hour boundary', () {
      final e = CronExpression.parse('0 * * * *');
      expect(e.nextOccurrence(at(2026, 10, 12, 8, 30)),
          DateTime(2026, 10, 12, 9, 0));
    });

    test('rolls across a day boundary', () {
      final e = CronExpression.parse('0 9 * * *');
      expect(e.nextOccurrence(at(2026, 10, 12, 10, 0)),
          DateTime(2026, 10, 13, 9, 0));
    });

    test('rolls across a month boundary', () {
      final e = CronExpression.parse('0 0 1 * *');
      expect(e.nextOccurrence(at(2026, 10, 12, 0, 0)),
          DateTime(2026, 11, 1, 0, 0));
    });

    test('rolls across a year boundary', () {
      final e = CronExpression.parse('0 0 1 1 *');
      expect(e.nextOccurrence(at(2026, 10, 12, 0, 0)),
          DateTime(2027, 1, 1, 0, 0));
    });

    test('weekday range only fires Mon-Fri', () {
      final e = CronExpression.parse('0 9 * * 1-5');
      // 2026-10-12 is a Monday; from Sat 10-10 00:00 the next hit is Mon 10-12.
      expect(e.nextOccurrence(at(2026, 10, 10, 0, 0)),
          DateTime(2026, 10, 12, 9, 0));
    });

    test('DOW 7 and 0 both mean Sunday', () {
      final e = CronExpression.parse('0 12 * * 7');
      // 2026-10-12 is Monday; next Sunday is 2026-10-18.
      expect(e.nextOccurrence(at(2026, 10, 12, 0, 0)),
          DateTime(2026, 10, 18, 12, 0));
    });

    test('DOM and DOW are OR-combined when both are restricted', () {
      // "0 0 1 * 0" = the 1st of the month OR any Sunday.
      final e = CronExpression.parse('0 0 1 * 0');
      // From Mon 2026-10-12: the next Sunday (10-18) comes before 11-01.
      expect(e.nextOccurrence(at(2026, 10, 12, 0, 0)),
          DateTime(2026, 10, 18, 0, 0));
    });

    test('a schedule that can never match returns null', () {
      final e = CronExpression.parse('0 0 30 2 *'); // Feb 30
      expect(e.nextOccurrence(at(2026, 10, 12, 0, 0)), isNull);
    });

    test('preset @hourly fires on the hour', () {
      final e = CronExpression.parse('@hourly');
      expect(e.nextOccurrence(at(2026, 10, 12, 8, 30)),
          DateTime(2026, 10, 12, 9, 0));
    });

    test('@weekly fires at Sunday midnight', () {
      final e = CronExpression.parse('@weekly');
      expect(e.nextOccurrence(at(2026, 10, 12, 8, 0)),
          DateTime(2026, 10, 18, 0, 0));
    });
  });
}