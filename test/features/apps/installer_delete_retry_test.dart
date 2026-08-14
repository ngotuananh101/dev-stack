import 'dart:io';

import 'package:dev_stack/core/services/log_service.dart';
import 'package:dev_stack/features/apps/data/app_installer_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Regression test for the "Update failed: Deletion failed, Access is denied
/// (errno 5)" crash that aborted a PHP version swap.
///
/// Even after killing the process tree, Windows can hold a DLL/file handle for
/// a few hundred ms after the owning process exits. A single
/// `Directory.delete(recursive: true)` then fails with Access Denied and
/// throws all the way up to `update()`, rolling the user back — even though the
/// folder would have been deletable moments later. [AppInstallerService.delete]
/// must retry the recursive delete with backoff on Access Denied (errno 5), and
/// must NOT retry on unrelated errors.
void main() {
  group('AppInstallerService.delete transient-lock retry', () {
    late Directory tempRoot;
    late AppInstallerService installer;

    setUp(() {
      tempRoot = Directory.systemTemp.createTempSync('dev_stack_delete_test_');
      installer = AppInstallerService(LogService(), _FakeRef());
    });

    tearDown(() {
      if (tempRoot.existsSync()) {
        try {
          tempRoot.deleteSync(recursive: true);
        } on FileSystemException {
          // Best-effort; OS temp sweeper handles the rest.
        }
      }
    });

    test(
      'retries and succeeds when the first delete throws Access Denied',
      () async {
        final target = Directory(p.join(tempRoot.path, 'php84-8.4.23'))
          ..createSync();
        File(p.join(target.path, 'php-cgi.exe')).writeAsStringSync('binary');

        var deleteCallCount = 0;

        await installer.deleteDirectoryWithRetriesForTest(
          target,
          attemptDelete: (dir) async {
            deleteCallCount++;
            if (deleteCallCount == 1) {
              throw PathAccessException(
                'Deletion failed, path = ${dir.path} '
                    '(OS Error: Access is denied, errno = 5)',
                const OSError('Access is denied', 5),
                'Deletion failed',
              );
            }
            // Second attempt: the OS handle has been released — actually remove.
            await dir.delete(recursive: true);
          },
          maxAttempts: 5,
          delayBetweenAttempts: const Duration(milliseconds: 1),
        );

        expect(deleteCallCount, 2);
        expect(
          target.existsSync(),
          isFalse,
          reason: 'folder should be gone after retry succeeded',
        );
      },
    );

    test(
      'gives up after maxAttempts and rethrows the last Access Denied',
      () async {
        final target = Directory(p.join(tempRoot.path, 'still-locked'))
          ..createSync();
        File(p.join(target.path, 'locked.dll')).writeAsStringSync('x');

        var deleteCallCount = 0;

        await expectLater(
          installer.deleteDirectoryWithRetriesForTest(
            target,
            attemptDelete: (dir) async {
              deleteCallCount++;
              throw PathAccessException(
                'Deletion failed, path = ${dir.path} '
                    '(OS Error: Access is denied, errno = 5)',
                const OSError('Access is denied', 5),
                'Deletion failed',
              );
            },
            maxAttempts: 3,
            delayBetweenAttempts: const Duration(milliseconds: 1),
          ),
          throwsA(isA<PathAccessException>()),
        );

        expect(deleteCallCount, 3);
      },
    );

    test(
      'does NOT retry on non-access errors (e.g. generic FileSystemException)',
      () async {
        final target = Directory(p.join(tempRoot.path, 'does-not-matter'));

        var deleteCallCount = 0;

        await expectLater(
          installer.deleteDirectoryWithRetriesForTest(
            target,
            attemptDelete: (dir) async {
              deleteCallCount++;
              throw FileSystemException('Not access-denied', dir.path);
            },
            maxAttempts: 5,
            delayBetweenAttempts: const Duration(milliseconds: 1),
          ),
          throwsA(isA<FileSystemException>()),
        );

        expect(
          deleteCallCount,
          1,
          reason: 'only Access Denied (errno 5) should be retried',
        );
      },
    );
  });
}

class _FakeRef implements Ref {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
