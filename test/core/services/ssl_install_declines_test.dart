import 'dart:io';

import 'package:dev_stack/core/services/ssl_install_declines.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;
  late String path;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ponta_declines_');
    path = '${tempDir.path}/ssl/declines.json';
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  test('a missing file declines nothing', () async {
    final declines = SslInstallDeclines(path);
    expect(await declines.read(), isEmpty);
    expect(await declines.isDeclined(SslInstallDeclines.nssTools), isFalse);
  });

  test('a recorded decline is remembered', () async {
    final declines = SslInstallDeclines(path);
    await declines.decline(SslInstallDeclines.nssTools);

    expect(await declines.isDeclined(SslInstallDeclines.nssTools), isTrue);
    expect(await declines.isDeclined(SslInstallDeclines.rootCa), isFalse);
  });

  test('declines are independent', () async {
    final declines = SslInstallDeclines(path);
    await declines.decline(SslInstallDeclines.rootCa);
    await declines.decline(SslInstallDeclines.nssTools);

    final read = SslInstallDeclines(path);
    expect(await read.isDeclined(SslInstallDeclines.rootCa), isTrue);
    expect(await read.isDeclined(SslInstallDeclines.nssTools), isTrue);
  });

  test('declining the same key twice keeps one entry', () async {
    final declines = SslInstallDeclines(path);
    await declines.decline(SslInstallDeclines.nssTools);
    await declines.decline(SslInstallDeclines.nssTools);

    expect((await declines.read()).length, 1);
  });

  test('clear forgets every decline', () async {
    final declines = SslInstallDeclines(path);
    await declines.decline(SslInstallDeclines.nssTools);
    await declines.decline(SslInstallDeclines.rootCa);

    await declines.clear();

    expect(await declines.read(), isEmpty);
    expect(await File(path).exists(), isFalse);
  });

  test('a corrupt file declines nothing instead of throwing', () async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString('{ not json');

    expect(await SslInstallDeclines(path).read(), isEmpty);
  });

  test('an unexpected shape declines nothing', () async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString('{"declines": "nss-tools"}');

    expect(await SslInstallDeclines(path).read(), isEmpty);
  });

  test('non-string entries are ignored', () async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString('{"declines": ["nss-tools", 7, null]}');

    expect(await SslInstallDeclines(path).read(), {
      SslInstallDeclines.nssTools,
    });
  });

  test('writing creates the parent directory', () async {
    final declines = SslInstallDeclines(path);
    await declines.decline(SslInstallDeclines.rootCa);

    expect(File(path).existsSync(), isTrue);
    expect(Directory('${tempDir.path}/ssl').existsSync(), isTrue);
  });
}
