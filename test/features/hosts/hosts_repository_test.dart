import 'package:dev_stack/features/hosts/data/hosts_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const start = '# [PONTA-START]';
  const end = '# [PONTA-END]';

  group('HostsRepository.replacePontaBlock', () {
    test('appends a new block when markers are absent', () {
      const hosts = '127.0.0.1 localhost';
      final out = HostsRepository.replacePontaBlock(hosts, start, end, [
        '127.0.0.1 app.test',
      ]);
      expect(out, contains(start));
      expect(out, contains('127.0.0.1 app.test'));
      expect(out, contains(end));
      expect(out, startsWith('127.0.0.1 localhost'));
      expect(out.endsWith('\n'), isTrue);
    });

    test('replaces an existing in-order block', () {
      const hosts = 'other\n$start\n127.0.0.1 old.test\n$end\ntrailing';
      final out = HostsRepository.replacePontaBlock(hosts, start, end, [
        '127.0.0.1 new.test',
      ]);
      expect(out, isNot(contains('old.test')));
      expect(out, contains('127.0.0.1 new.test'));
      expect(out, contains('trailing'));
      expect(out, contains('other'));
    });

    test('does not throw RangeError when end marker precedes start marker', () {
      const hosts = '$end\n$start\n127.0.0.1 orphan\nother';
      final out = HostsRepository.replacePontaBlock(hosts, start, end, [
        '127.0.0.1 fixed.test',
      ]);
      expect(out, contains(start));
      expect(out, contains('127.0.0.1 fixed.test'));
      expect(out, contains(end));
      expect(out.split(start), hasLength(3));
      expect(out.split(end), hasLength(3));
    });

    test('replaces only the first block for duplicated markers', () {
      const hosts =
          '$start\n127.0.0.1 a.test\n$end\n$start\n127.0.0.1 b.test\n$end\n';
      final out = HostsRepository.replacePontaBlock(hosts, start, end, [
        '127.0.0.1 replaced.test',
      ]);
      // The first block is replaced; the second is left untouched (best-effort).
      expect(out, isNot(contains('127.0.0.1 a.test')));
      expect(out, contains('127.0.0.1 b.test'));
      expect(out, contains('127.0.0.1 replaced.test'));
      // Two start/end pairs survive from the input + replacement.
      expect(out.split(start), hasLength(3));
      expect(out.split(end), hasLength(3));
    });
  });
}
