import 'dart:io';
import 'package:dev_stack/features/apps/data/php_runtime_bundle.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import '../../helpers/php_bundle_fixture.dart';

void main() {
  late Directory parent;
  late Directory root;
  setUp(() {
    parent = Directory.systemTemp.createTempSync('php_manifest_');
    root = createPhpBundleFixture(parent);
  });
  tearDown(() => parent.deleteSync(recursive: true));

  test(
    'reads producer schema and exact launchers, then verifies module hashes',
    () async {
      final bundle = PhpRuntimeBundle.load(root.path)!;
      expect(bundle.version, '8.4.27');
      expect(bundle.pathFor('cli'), p.join(root.path, 'bin/php'));
      expect(bundle.sharedModules.single.name, 'redis');
      await bundle.validateInstallation('8.4.27');
    },
  );
  test('only absent manifest permits a legacy fallback', () {
    File(p.join(root.path, 'manifest.json')).deleteSync();
    expect(PhpRuntimeBundle.load(root.path), isNull);
    File(p.join(root.path, 'manifest.json')).writeAsStringSync('{}');
    expect(() => PhpRuntimeBundle.load(root.path), throwsFormatException);
  });
  for (final field in [
    'schema_version',
    'runtime',
    'architecture',
    'target',
    'verification',
  ]) {
    test('rejects unsupported $field', () {
      editBundleManifest(
        root,
        (m) => m[field] = field == 'schema_version' ? 2 : 'unsupported',
      );
      expect(() => PhpRuntimeBundle.load(root.path), throwsFormatException);
    });
  }
  test('rejects a glibc target even when everything else is valid', () {
    editBundleManifest(root, (m) => m['target'] = 'glibc');
    expect(() => PhpRuntimeBundle.load(root.path), throwsFormatException);
  });
  for (final path in [
    '/tmp/php',
    '../php',
    'bin/../php',
    'bin//php',
    './bin/php',
    r'bin\php',
    'bin/php\n',
    'libexec/php',
  ]) {
    test('rejects unsafe or non-launcher CLI path $path', () {
      editBundleManifest(root, (m) => m['paths']['cli'] = path);
      expect(() => PhpRuntimeBundle.load(root.path), throwsFormatException);
    });
  }
  test('rejects a launcher symlink escaping the bundle root', () {
    final file = File(p.join(root.path, 'bin/php'))..deleteSync();
    final outside = File(p.join(parent.path, 'outside'))
      ..writeAsStringSync('outside');
    Link(file.path).createSync(outside.path);
    expect(() => PhpRuntimeBundle.load(root.path), throwsFormatException);
  });
  test('rejects a launcher symlink pointing directly to a backing binary', () {
    final file = File(p.join(root.path, 'bin/php'))..deleteSync();
    Link(file.path).createSync('../libexec/php');
    expect(() => PhpRuntimeBundle.load(root.path), throwsFormatException);
  });
  test('rejects launchers reached through a symlinked bin directory', () {
    File(
      p.join(root.path, 'bin/php-ext'),
    ).copySync(p.join(root.path, 'libexec/php-ext'));
    Directory(p.join(root.path, 'bin')).deleteSync(recursive: true);
    Link(p.join(root.path, 'bin')).createSync('libexec');
    // The leaf is still regular, but the ancestor redirects it to libexec.
    expect(
      FileSystemEntity.typeSync(
        p.join(root.path, 'bin/php'),
        followLinks: false,
      ),
      FileSystemEntityType.file,
    );
    expect(() => PhpRuntimeBundle.load(root.path), throwsFormatException);
  });
  test('rejects duplicate shared registry entries', () {
    editBundleManifest(
      root,
      (m) => m['shared_modules'].add(
        Map<String, dynamic>.from(m['shared_modules'][0]),
      ),
    );
    expect(() => PhpRuntimeBundle.load(root.path), throwsFormatException);
  });
  test('rejects static/shared overlap', () {
    editBundleManifest(root, (m) => m['php']['static_modules'].add('redis'));
    expect(() => PhpRuntimeBundle.load(root.path), throwsFormatException);
  });
  test('rejects an unsupported extension directive', () {
    editBundleManifest(
      root,
      (m) => m['shared_modules'][0]['directive'] = 'shell',
    );
    expect(() => PhpRuntimeBundle.load(root.path), throwsFormatException);
  });
  test('rejects a missing shared module file', () {
    File(p.join(root.path, 'lib/php/extensions/redis.so')).deleteSync();
    expect(() => PhpRuntimeBundle.load(root.path), throwsFormatException);
  });
  test('rejects a file in place of an FPM scan directory', () {
    final scan = Directory(p.join(root.path, 'etc/fpm/conf.d'))..deleteSync();
    File(scan.path).writeAsStringSync('not a directory');
    expect(() => PhpRuntimeBundle.load(root.path), throwsFormatException);
  });
  for (final value in ['8.4', '8.4.27RC1', null]) {
    test('rejects non-patch PHP version $value', () {
      editBundleManifest(root, (m) => m['php']['version'] = value);
      expect(() => PhpRuntimeBundle.load(root.path), throwsFormatException);
    });
  }
  for (final field in ['name', 'sha256', 'enabled_by_default']) {
    test('rejects invalid shared module $field', () {
      editBundleManifest(
        root,
        (m) => m['shared_modules'][0][field] = field == 'enabled_by_default'
            ? {'cli': true, 'fpm': 'false'}
            : 'invalid!',
      );
      expect(() => PhpRuntimeBundle.load(root.path), throwsFormatException);
    });
  }
  test(
    'rejects installation version mismatch and corrupted shared module',
    () async {
      final bundle = PhpRuntimeBundle.load(root.path)!;
      await expectLater(
        bundle.validateInstallation('8.4.26'),
        throwsFormatException,
      );
      File(bundle.sharedModules.single.path).writeAsStringSync('corrupt');
      await expectLater(
        bundle.validateInstallation('8.4.27'),
        throwsFormatException,
      );
    },
  );
}
