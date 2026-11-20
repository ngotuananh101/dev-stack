import 'dart:io';
import 'package:dev_stack/features/apps/data/app_launcher.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  late File executable;
  setUp(() {
    root = Directory.systemTemp.createTempSync('launcher_');
    executable = File(p.join(root.path, 'app dir', 'MongoDB Compass;not-shell'))
      ..createSync(recursive: true);
  });
  tearDown(() => root.deleteSync(recursive: true));

  test(
    'Linux launches the absolute path detached with no shell and the app directory',
    () async {
      final calls = <String>[];
      final launcher = AppLauncher(
        isLinux: true,
        startDetached: (path, arguments, workingDirectory) async {
          calls.add(path);
          expect(arguments, isEmpty);
          expect(workingDirectory, executable.parent.path);
        },
        runWindows: (_, _) async => fail('Windows command on Linux'),
      );
      await launcher.open(executable.path);
      expect(calls, [executable.absolute.path]);
    },
  );
  test('Windows keeps its cmd start argument boundaries', () async {
    var launched = false;
    final launcher = AppLauncher(
      isLinux: false,
      startDetached: (_, _, _) async => fail('Linux command on Windows'),
      runWindows: (path, args) async {
        launched = true;
        expect(path, 'cmd');
        expect(args, ['/c', 'start', '', executable.path]);
      },
    );
    await launcher.open(executable.path);
    expect(launched, isTrue);
  });
  test('missing executable fails before launching', () async {
    final launcher = AppLauncher(
      isLinux: true,
      startDetached: (_, _, _) async => fail('Must not launch'),
    );
    await expectLater(
      launcher.open(p.join(root.path, 'missing')),
      throwsA(isA<FileSystemException>()),
    );
  });
  test('process start errors propagate to the caller', () async {
    final failure = ProcessException(executable.path, [], 'permission denied');
    final launcher = AppLauncher(
      isLinux: true,
      startDetached: (_, _, _) async => throw failure,
    );
    await expectLater(launcher.open(executable.path), throwsA(same(failure)));
  });
}
