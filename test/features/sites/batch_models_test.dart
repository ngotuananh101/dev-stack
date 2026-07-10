import 'package:dev_stack/features/sites/domain/batch_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CancelToken', () {
    test('starts not cancelled', () {
      expect(CancelToken().isCancelled, isFalse);
    });

    test('cancel() sets isCancelled', () {
      final token = CancelToken();
      token.cancel();
      expect(token.isCancelled, isTrue);
    });
  });

  group('BatchProgress.fraction', () {
    test('is 0 when total is 0', () {
      const p = BatchProgress(
        current: 0,
        total: 0,
        currentLabel: '',
        phase: BatchPhase.processing,
      );
      expect(p.fraction, 0.0);
    });

    test('is current/total otherwise', () {
      const p = BatchProgress(
        current: 3,
        total: 6,
        currentLabel: 'a.test',
        phase: BatchPhase.processing,
      );
      expect(p.fraction, 0.5);
    });
  });
}
