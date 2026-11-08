import 'dart:io';

import 'package:dev_stack/features/apps/data/runtime_bundle.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../helpers/runtime_bundle_fixture.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync(
      'runtime_bundle_manifest_test_',
    );
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('Apache launchers come from the launchers list', () {
    final root = createApacheBundleFixture(tempDir);
    final m = RuntimeBundleManifest.load(root.path)!;
    expect(m.runtime, 'apache');
    expect(m.version, '2.4.70');
    expect(m.declaresLauncher('httpd'), isTrue);
    expect(m.declaresLauncher('apachectl'), isTrue);
    expect(m.declaresLauncher('nonexistent'), isFalse);
    expect(m.launcherPath('httpd'), p.join(root.path, 'bin', 'httpd'));
  });

  test('PostgreSQL launchers come from the binaries list basenames', () {
    final root = createPostgresqlBundleFixture(tempDir);
    final m = RuntimeBundleManifest.load(root.path)!;
    expect(m.runtime, 'postgresql');
    expect(m.version, '18.6');
    expect(m.declaresLauncher('postgres'), isTrue);
    expect(m.declaresLauncher('initdb'), isTrue);
    expect(m.declaresLauncher('absent'), isFalse);
    expect(m.launcherPath('postgres'), p.join(root.path, 'bin', 'postgres'));
    expect(() => m.launcherPath('absent'), throwsArgumentError);
  });

  test('a PHP or malformed manifest is not a runtime bundle', () {
    final root = Directory(p.join(tempDir.path, 'invalid'))..createSync();
    File(
      p.join(root.path, 'manifest.json'),
    ).writeAsStringSync('{"runtime":"php"}');
    expect(RuntimeBundleManifest.load(root.path), isNull);

    File(
      p.join(root.path, 'manifest.json'),
    ).writeAsStringSync('not json at all');
    expect(RuntimeBundleManifest.load(root.path), isNull);

    File(
      p.join(root.path, 'manifest.json'),
    ).writeAsStringSync('{"schema_version":2,"runtime":"apache"}');
    expect(RuntimeBundleManifest.load(root.path), isNull);

    File(
      p.join(root.path, 'manifest.json'),
    ).writeAsStringSync('{"schema_version":1,"runtime":"unknown"}');
    expect(RuntimeBundleManifest.load(root.path), isNull);

    File(p.join(root.path, 'manifest.json')).writeAsStringSync(
      '{"schema_version":1,"runtime":"apache","apache":{"version":"invalid"}}',
    );
    expect(RuntimeBundleManifest.load(root.path), isNull);
  });

  test('returns null when manifest is absent or directory missing', () {
    final emptyDir = Directory(p.join(tempDir.path, 'empty'))..createSync();
    expect(RuntimeBundleManifest.load(emptyDir.path), isNull);
    expect(
      RuntimeBundleManifest.load(p.join(tempDir.path, 'does_not_exist')),
      isNull,
    );
  });
}
