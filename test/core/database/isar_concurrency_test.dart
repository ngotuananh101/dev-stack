import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:dev_stack/core/database/isar_provider.dart';

class _FakeIsar extends Fake implements Isar {
  _FakeIsar({this.isOpen = true});

  @override
  bool isOpen;

  @override
  Future<bool> close({bool deleteFromDisk = false}) async {
    isOpen = false;
    return true;
  }
}

void main() {
  tearDown(() async {
    await IsarInstance.close();
  });

  group('IsarInstance Concurrency and Serialization', () {
    test(
      'concurrent calls return same instance and opener is invoked exactly once',
      () async {
        int openerCalls = 0;
        final fakeIsar = _FakeIsar();

        Future<Isar> testOpener() async {
          openerCalls++;
          await Future.delayed(const Duration(milliseconds: 50));
          return fakeIsar;
        }

        // 10 concurrent callers
        final futures = List<Future<Isar>>.generate(
          10,
          (_) => IsarInstance.getInstance(opener: testOpener),
        );

        final results = await Future.wait(futures);

        expect(openerCalls, equals(1));
        for (final instance in results) {
          expect(identical(instance, fakeIsar), isTrue);
        }
      },
    );

    test('sequential calls reuse cached instance without re-invoking opener', () async {
      int openerCalls = 0;
      final fakeIsar = _FakeIsar();

      Future<Isar> testOpener() async {
        openerCalls++;
        return fakeIsar;
      }

      final first = await IsarInstance.getInstance(opener: testOpener);
      final second = await IsarInstance.getInstance(opener: testOpener);

      expect(openerCalls, equals(1));
      expect(identical(first, second), isTrue);
      expect(identical(first, fakeIsar), isTrue);
    });

    test(
      'error in opener propagates to all concurrent waiters and resets lock for subsequent calls',
      () async {
        int openerCalls = 0;

        Future<Isar> failingOpener() async {
          openerCalls++;
          await Future.delayed(const Duration(milliseconds: 20));
          throw Exception('Failed to open database');
        }

        // 5 concurrent callers failing
        final futures = List.generate(
          5,
          (_) => IsarInstance.getInstance(opener: failingOpener),
        );

        for (final future in futures) {
          expect(future, throwsA(isA<Exception>()));
        }

        await Future.wait(
          futures.map((f) => f.catchError((_) => _FakeIsar())),
        );

        expect(openerCalls, equals(1));

        // Subsequent call should succeed and retry opening
        final fakeIsar = _FakeIsar();
        Future<Isar> successfulOpener() async {
          openerCalls++;
          return fakeIsar;
        }

        final recovered = await IsarInstance.getInstance(opener: successfulOpener);
        expect(openerCalls, equals(2));
        expect(identical(recovered, fakeIsar), isTrue);
      },
    );

    test('close clears cached instance and allows reopening', () async {
      int openerCalls = 0;
      final fakeIsar1 = _FakeIsar();
      final fakeIsar2 = _FakeIsar();

      Future<Isar> testOpener() async {
        openerCalls++;
        return openerCalls == 1 ? fakeIsar1 : fakeIsar2;
      }

      final first = await IsarInstance.getInstance(opener: testOpener);
      expect(identical(first, fakeIsar1), isTrue);
      expect(fakeIsar1.isOpen, isTrue);

      await IsarInstance.close();
      expect(fakeIsar1.isOpen, isFalse);

      final second = await IsarInstance.getInstance(opener: testOpener);
      expect(openerCalls, equals(2));
      expect(identical(second, fakeIsar2), isTrue);
    });

    test('if cached instance has isOpen == false, opener is invoked again', () async {
      int openerCalls = 0;
      final fakeIsar1 = _FakeIsar(isOpen: true);
      final fakeIsar2 = _FakeIsar(isOpen: true);

      Future<Isar> testOpener() async {
        openerCalls++;
        return openerCalls == 1 ? fakeIsar1 : fakeIsar2;
      }

      final first = await IsarInstance.getInstance(opener: testOpener);
      expect(identical(first, fakeIsar1), isTrue);
      expect(openerCalls, equals(1));

      // Simulate external close on instance
      fakeIsar1.isOpen = false;

      final second = await IsarInstance.getInstance(opener: testOpener);
      expect(identical(second, fakeIsar2), isTrue);
      expect(openerCalls, equals(2));
    });
  });
}
