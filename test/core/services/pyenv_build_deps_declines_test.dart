import 'dart:io';

import 'package:dev_stack/core/services/pyenv_build_deps_declines.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;
  late PyenvBuildDepsDeclines declines;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ponta_pyenv_declines_');
    declines = PyenvBuildDepsDeclines('${tempDir.path}/declines.json');
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  test('a missing file declines nothing', () async {
    expect(await declines.read(), isEmpty);
    expect(
      await declines.isDeclined('openssl-devel,readline-devel'),
      isFalse,
    );
  });

  test('a declined key reads back as declined', () async {
    await declines.decline('openssl-devel,readline-devel');
    expect(
      await declines.isDeclined('openssl-devel,readline-devel'),
      isTrue,
    );
  });

  test('clear forgets every decline', () async {
    await declines.decline('openssl-devel');
    await declines.clear();
    expect(await declines.read(), isEmpty);
  });

  test('a corrupt file reads as an empty set and never throws', () async {
    await File('${tempDir.path}/declines.json').writeAsString('not json');
    expect(await declines.read(), isEmpty);
  });
}
