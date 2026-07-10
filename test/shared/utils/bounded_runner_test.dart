import 'package:dev_stack/features/sites/domain/batch_models.dart';
import 'package:dev_stack/shared/utils/bounded_runner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('runBounded', () {
    test('returns results in original order', () async {
      final items = [1, 2, 3, 4, 5];
      final results = await runBounded<int, int>(
        items,
        2,
        (item, index) async => item * 10,
      );
      expect(results, [10, 20, 30, 40, 50]);
    });

    test('never exceeds max concurrency', () async {
      var inFlight = 0;
      var maxInFlight = 0;
      final items = List.generate(20, (i) => i);
      await runBounded<int, int>(items, 4, (item, index) async {
        inFlight++;
        if (inFlight > maxInFlight) maxInFlight = inFlight;
        await Future<void>.delayed(const Duration(milliseconds: 5));
        inFlight--;
        return item;
      });
      expect(maxInFlight, lessThanOrEqualTo(4));
    });

    test('stops admitting new tasks after cancel', () async {
      final token = CancelToken();
      var started = 0;
      final items = List.generate(20, (i) => i);
      await runBounded<int, int>(
        items,
        2,
        (item, index) async {
          started++;
          if (started == 3) token.cancel();
          await Future<void>.delayed(const Duration(milliseconds: 5));
          return item;
        },
        cancel: token,
      );
      // Some tasks admitted before cancel; not all 20 should run.
      expect(started, lessThan(20));
    });
  });
}
