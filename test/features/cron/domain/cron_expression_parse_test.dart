import 'package:dev_stack/features/cron/domain/cron_expression.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CronExpression parsing', () {
    test('parses every wildcard field', () {
      final e = CronExpression.parse('* * * * *');
      expect(e.minutes.length, 60);
      expect(e.hours.length, 24);
      expect(e.daysOfMonth.length, 31);
      expect(e.months.length, 12);
      expect(e.daysOfWeek.length, 7);
      expect(e.domRestricted, isFalse);
      expect(e.dowRestricted, isFalse);
    });

    test('expands a step list', () {
      final e = CronExpression.parse('*/15 * * * *');
      expect(e.minutes, [0, 15, 30, 45]);
    });

    test('expands a range', () {
      final e = CronExpression.parse('0 9 * * 1-5');
      expect(e.daysOfWeek, [1, 2, 3, 4, 5]);
      expect(e.dowRestricted, isTrue);
    });

    test('expands a comma list combined with a range', () {
      final e = CronExpression.parse('1,15,30-32 * * * *');
      expect(e.minutes, [1, 15, 30, 31, 32]);
    });

    test('range with step', () {
      final e = CronExpression.parse('0-30/10 * * * *');
      expect(e.minutes, [0, 10, 20, 30]);
    });

    test('normalizes day-of-week 7 to Sunday (0)', () {
      final e = CronExpression.parse('0 0 * * 7');
      expect(e.daysOfWeek, [0]);
    });

    test('expands presets', () {
      expect(CronExpression.parse('@hourly').minutes, [0]);
      expect(CronExpression.parse('@daily').hours, [0]);
      expect(CronExpression.parse('@midnight').hours, [0]);
      expect(CronExpression.parse('@weekly').daysOfWeek, [0]);
      expect(CronExpression.parse('@monthly').daysOfMonth, [1]);
      expect(CronExpression.parse('@yearly').months, [1]);
      expect(CronExpression.parse('@annually').months, [1]);
    });

    test('rejects malformed expressions', () {
      for (final bad in [
        '',
        '* * * *',        // 4 fields
        '* * * * * *',    // 6 fields
        '60 * * * *',     // minute out of range
        '* 24 * * *',     // hour out of range
        '* * 0 * *',      // dom must start at 1
        '* * 32 * *',
        '* * * 13 *',
        '* * * * 8',
        'a * * * *',
        '*/0 * * * *',    // zero step
        '5-1 * * * *',    // inverted range
        '@nope',
      ]) {
        expect(CronExpression.isValid(bad), isFalse, reason: bad);
        expect(CronExpression.validate(bad), isNotNull, reason: bad);
      }
    });

    test('validate returns null for a good expression', () {
      expect(CronExpression.validate('*/5 0 1,15 * 1-5'), isNull);
      expect(CronExpression.isValid('@weekly'), isTrue);
    });
  });
}