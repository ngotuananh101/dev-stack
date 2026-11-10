import 'dart:convert';
import 'dart:io';

import 'package:dev_stack/shared/utils/log_tail_reader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('log_tail_test_');
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  File write(String name, String content) {
    final file = File('${tmp.path}/$name');
    file.writeAsStringSync(content);
    return file;
  }

  test('missing file yields an empty tail instead of throwing', () async {
    final tail = await readLogTail(File('${tmp.path}/nope.log'));
    expect(tail.lines, isEmpty);
    expect(tail.truncated, isFalse);
  });

  test('empty file yields an empty tail', () async {
    final tail = await readLogTail(write('empty.log', ''));
    expect(tail.lines, isEmpty);
  });

  test('returns every line when the file fits the budget', () async {
    final tail = await readLogTail(write('small.log', 'one\ntwo\nthree\n'));
    expect(tail.lines, ['one', 'two', 'three']);
    expect(tail.truncated, isFalse);
  });

  test('reads only the requested byte budget from the end', () async {
    // 10k lines of 10 chars: far larger than the 1 KB budget.
    final content = [for (var i = 0; i < 10000; i++) 'line $i'].join('\n');
    final file = write('big.log', '$content\n');

    final tail = await readLogTail(file, maxBytes: 1024);

    expect(tail.truncated, isTrue, reason: 'older content was skipped');
    expect(tail.bytes, lessThanOrEqualTo(1024));
    expect(tail.lines, isNotEmpty);
    // The newest line must always survive, and no row may be a half-line
    // produced by seeking into the middle of the file.
    expect(tail.lines.last, 'line 9999');
    for (final line in tail.lines) {
      expect(line, matches(RegExp(r'^line \d+$')));
    }
  });

  test('caps the number of returned lines and reports truncation', () async {
    final tail = await readLogTail(
      write('many.log', [for (var i = 0; i < 100; i++) 'l$i'].join('\n')),
      maxLines: 10,
    );

    expect(tail.lines, hasLength(10));
    expect(tail.lines.first, 'l90');
    expect(tail.lines.last, 'l99');
    expect(tail.truncated, isTrue);
  });

  test('survives malformed UTF-8 instead of throwing', () async {
    final file = File('${tmp.path}/binary.log');
    file.writeAsBytesSync([0x41, 0x0A, 0xff, 0xfe, 0x0A, 0x42]);

    final tail = await readLogTail(file);

    expect(tail.lines.first, 'A');
    expect(tail.lines.last, 'B');
  });

  test('a file with one very long line still parses', () async {
    final long = 'x' * 5000;
    final tail = await readLogTail(
      write('long.log', utf8.decode(utf8.encode('$long\nnext\n'))),
      maxBytes: 100 * 1024,
    );
    expect(tail.lines.last, 'next');
  });
}
