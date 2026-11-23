import 'dart:async';
import 'dart:convert';

import 'package:dev_stack/core/services/process_output.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'discarded process output is drained without decoding invalid bytes',
    () async {
      var read = 0;
      final errors = <Object>[];
      final data = <String>[];
      Stream<List<int>> output() async* {
        read++;
        yield [0xff];
        read++;
        yield [0xfe];
      }

      final subscription = listenToProcessOutput(
        output(),
        discard: true,
        onData: data.add,
        onError: errors.add,
      );
      await subscription.asFuture<void>();
      expect(read, 2);
      expect(data, isEmpty);
      expect(errors, isEmpty);
    },
  );

  test('visible output retains UTF-8 decoding across chunks', () async {
    final data = <String>[];
    final subscription = listenToProcessOutput(
      Stream.fromIterable([
        [0xe2],
        [0x82, 0xac, 10],
      ]),
      discard: false,
      onData: data.add,
      onError: (error) => fail('$error'),
    );
    await subscription.asFuture<void>();
    expect(data.join(), '€\n');
  });

  test(
    'cancelling discarded output cancels the underlying subscription',
    () async {
      var cancelled = false;
      final output = StreamController<List<int>>(
        onCancel: () => cancelled = true,
      );
      final subscription = listenToProcessOutput(
        output.stream,
        discard: true,
        onData: (_) => fail('Discarded bytes must not become UI log data'),
        onError: (error) => fail('$error'),
      );
      await subscription.cancel();
      await output.close();
      expect(cancelled, isTrue);
    },
  );

  test('discard mode still reports underlying stream errors', () async {
    final error = StateError('pipe failed');
    final errors = <Object>[];
    final done = Completer<void>();
    final output = StreamController<List<int>>();
    final subscription = listenToProcessOutput(
      output.stream,
      discard: true,
      onData: (_) => fail('Unexpected decoded data'),
      onError: errors.add,
    )..onDone(done.complete);
    output.addError(error);
    output.add(utf8.encode('still drained'));
    await output.close();
    await done.future;
    await subscription.cancel();
    expect(errors, [error]);
  });
}
