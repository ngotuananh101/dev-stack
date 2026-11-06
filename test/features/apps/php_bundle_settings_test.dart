import 'dart:io';
import 'package:dev_stack/features/apps/data/php_settings_provider.dart';
import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import '../../helpers/php_bundle_fixture.dart';

void main() {
  late Directory parent;
  late Directory root;
  late AppModel app;
  final settings = PhpSettings();
  setUp(() async {
    parent = Directory.systemTemp.createTempSync('php_settings_');
    root = createPhpBundleFixture(parent);
    await Process.run('chmod', ['755', p.join(root.path, 'bin/php-ext')]);
    app = AppModel(
      appId: 'php84',
      name: 'PHP 8.4',
      categories: ['runtime'],
      groupName: 'php',
      location: root.path,
    );
  });
  tearDown(() => parent.deleteSync(recursive: true));

  test('INI editor reads and saves manifest PHP ini', () async {
    expect(resolvePhpIniPath(app), p.join(root.path, 'etc/php.ini'));
    expect(await settings.readPhpIni(app), contains('memory_limit'));
    await settings.savePhpIni(app, 'memory_limit = 256M\n');
    expect(
      File(p.join(root.path, 'etc/php.ini')).readAsStringSync(),
      'memory_limit = 256M\n',
    );
  });
  test(
    'shared registry omits static modules and reads FPM active state',
    () async {
      File(
        p.join(root.path, 'etc/fpm/conf.d/50-redis.ini'),
      ).writeAsStringSync('extension=redis.so\n');
      final ext = await settings.getExtensions(app);
      expect(ext.map((e) => e.name), ['redis']);
      expect(ext.single.isEnabled, isTrue);
      expect(ext.single.isInstalled, isTrue);
      expect(ext.single.isZend, isFalse);
    },
  );
  test(
    'real manager toggles CLI and FPM scans without changing common ini',
    () async {
      final original = await settings.readPhpIni(app);
      final ext = (await settings.getExtensions(app)).single;
      final note = await settings.toggleExtension(app, ext, true);
      expect(note, contains('restart'));
      for (final sapi in ['cli', 'fpm']) {
        expect(
          File(
            p.join(root.path, 'etc/$sapi/conf.d/50-redis.ini'),
          ).readAsStringSync(),
          'extension=redis.so\n',
        );
      }
      expect(await settings.readPhpIni(app), original);
      await settings.toggleExtension(app, ext, false);
      expect((await settings.getExtensions(app)).single.isEnabled, isFalse);
    },
  );
  test('corrupted shared module cannot be enabled or reloaded', () async {
    final ext = (await settings.getExtensions(app)).single;
    File(
      p.join(root.path, 'lib/php/extensions/redis.so'),
    ).writeAsStringSync('corrupt');
    app.servicePid = 1234;
    final calls = <List<String>>[];
    await expectLater(
      settings.toggleExtension(
        app,
        ext,
        true,
        runProcess: (exe, args) async {
          calls.add([exe, ...args]);
          if (exe == 'kill') return ProcessResult(0, 0, '', '');
          return Process.run(exe, args);
        },
      ),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('SHA256 mismatch'),
        ),
      ),
    );
    expect(calls, isEmpty);
    for (final sapi in ['cli', 'fpm']) {
      expect(
        File(p.join(root.path, 'etc/$sapi/conf.d/50-redis.ini')).existsSync(),
        isFalse,
      );
    }
  });
  test('corrupted shared module can still be disabled', () async {
    final ext = (await settings.getExtensions(app)).single;
    await settings.toggleExtension(app, ext, true);
    File(
      p.join(root.path, 'lib/php/extensions/redis.so'),
    ).writeAsStringSync('corrupt');
    await settings.toggleExtension(app, ext, false);
    expect((await settings.getExtensions(app)).single.isEnabled, isFalse);
    for (final sapi in ['cli', 'fpm']) {
      expect(
        File(p.join(root.path, 'etc/$sapi/conf.d/50-redis.ini')).existsSync(),
        isFalse,
      );
    }
  });
  test(
    'rejects unknown registry modules and common-INI directives before execution',
    () async {
      var calls = 0;
      Future<ProcessResult> runner(String exe, List<String> args) async {
        calls++;
        return ProcessResult(0, 0, '', '');
      }

      final fake = PhpExtension(
        name: 'pdo',
        fileName: 'pdo.so',
        isEnabled: false,
        isFoundInIni: false,
        isZend: false,
      );
      await expectLater(
        settings.toggleExtension(app, fake, true, runProcess: runner),
        throwsStateError,
      );
      final ext = (await settings.getExtensions(app)).single;
      File(p.join(root.path, 'etc/php.ini')).writeAsStringSync(
        'extension="${root.path}/lib/php/extensions/redis.so"\n',
      );
      await expectLater(
        settings.toggleExtension(app, ext, false, runProcess: runner),
        throwsStateError,
      );
      expect(calls, 0);
    },
  );
  test(
    'failed manager command propagates and successful toggle reloads master only',
    () async {
      final ext = (await settings.getExtensions(app)).single;
      await expectLater(
        settings.toggleExtension(
          app,
          ext,
          true,
          runProcess: (exe, args) async => ProcessResult(0, 2, '', 'failed'),
        ),
        throwsStateError,
      );
      app.servicePid = 1234;
      final calls = <List<String>>[];
      final note = await settings.toggleExtension(
        app,
        ext,
        true,
        runProcess: (exe, args) async {
          calls.add([exe, ...args]);
          return ProcessResult(0, 0, '', '');
        },
      );
      expect(note, isNull);
      expect(calls, [
        [p.join(root.path, 'bin/php-ext'), 'enable', 'redis', 'all'],
        ['kill', '-USR2', '--', '1234'],
      ]);
    },
  );
  test(
    'failed master reload returns a restart note after a successful toggle',
    () async {
      final ext = (await settings.getExtensions(app)).single;
      app.servicePid = 1234;
      final calls = <String>[];
      final note = await settings.toggleExtension(
        app,
        ext,
        true,
        runProcess: (exe, args) async {
          calls.add(exe);
          return ProcessResult(0, exe == 'kill' ? 1 : 0, '', '');
        },
      );
      expect(note, contains('restart'));
      expect(calls, [p.join(root.path, 'bin/php-ext'), 'kill']);
    },
  );
  test('legacy custom Linux disable removes .so directives', () async {
    File(p.join(root.path, 'manifest.json')).deleteSync();
    File(
      p.join(root.path, 'php.ini'),
    ).writeAsStringSync('extension=redis.so\nmemory_limit=128M\n');
    final ext = PhpExtension(
      name: 'redis',
      fileName: 'redis.so',
      isEnabled: true,
      isFoundInIni: true,
      isZend: false,
    );
    await settings.toggleExtension(app, ext, false);
    expect(
      File(p.join(root.path, 'php.ini')).readAsStringSync(),
      isNot(contains('extension=')),
    );
  });
}
