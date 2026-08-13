import 'package:dev_stack/core/services/log_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LogService.logsOlderThan', () {
    test('keeps files within the retention window', () {
      final today = DateTime(2026, 8, 13);
      final recent = [
        DateTime(2026, 8, 13),
        DateTime(2026, 8, 12),
        DateTime(2026, 8, 1),
      ];
      final stale = LogService.logsOlderThan(
        recent,
        today: today,
        retentionDays: 30,
      );
      expect(stale, isEmpty);
    });

    test('flags files older than the retention window', () {
      final today = DateTime(2026, 8, 13);
      final dates = [
        DateTime(2026, 8, 13), // today — keep
        DateTime(2026, 7, 13), // exactly 31 days — stale
        DateTime(2026, 6, 1), // older — stale
      ];
      final stale = LogService.logsOlderThan(
        dates,
        today: today,
        retentionDays: 30,
      );
      expect(stale.length, 2);
      expect(stale, contains(DateTime(2026, 7, 13)));
      expect(stale, contains(DateTime(2026, 6, 1)));
    });
  });
}
