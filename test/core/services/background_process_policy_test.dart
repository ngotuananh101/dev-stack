import 'dart:io';

import 'package:dev_stack/core/services/background_process.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('background process policy', () {
    test('runner preserves output and exit code', () async {
      if (!Platform.isWindows) return;

      final result = await BackgroundProcess.run('powershell', [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        '[Console]::Out.Write("background-ok")',
      ]);

      expect(result.stderr, isEmpty);
      expect(result.exitCode, 0);
      expect(result.stdout, 'background-ok');
    });

    test('managed background process exposes an exit code', () async {
      if (!Platform.isWindows) return;

      final process = await BackgroundProcess.start('cmd.exe', [
        '/c',
        'exit',
        '7',
      ]);

      expect(await process.exitCode, 7);
    });

    test('managed background process stops the real child', () async {
      if (!Platform.isWindows) return;

      final process = await BackgroundProcess.start('powershell', [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        'Start-Sleep -Seconds 30',
      ]);

      await BackgroundProcess.stopManaged(process);
      expect(
        await process.exitCode.timeout(const Duration(seconds: 5)),
        isNot(equals(0)),
      );
    });

    test('background PowerShell calls use the shared runner', () async {
      const files = [
        'lib/core/config/app_config.dart',
        'lib/core/services/path_service.dart',
        'lib/core/services/ssl_service.dart',
        'lib/features/hosts/data/hosts_repository.dart',
        'lib/features/settings/data/settings_provider.dart',
      ];

      for (final path in files) {
        final source = await File(path).readAsString();
        expect(
          RegExp(
            r'''(?<!Background)Process\.run\([\r\n\s]*['"]powershell['"]''',
          ).hasMatch(source),
          isFalse,
          reason: '$path must not launch a visible PowerShell process',
        );
      }
    });

    test('shared runner uses detached mode for webservers', () async {
      final runnerSource = await File(
        'lib/core/services/background_process.dart',
      ).readAsString();

      expect(runnerSource, contains('ProcessStartMode.detached'));
    });

    test('site lifecycle subprocesses use the shared runner', () async {
      final sslSource = await File(
        'lib/core/services/ssl_service.dart',
      ).readAsString();
      final serviceSource = await File(
        'lib/features/apps/data/app_service_manager.dart',
      ).readAsString();

      expect(
        RegExp(
          r'(?<!Background)Process\.run\([\r\n\s]*mkcertPath',
        ).hasMatch(sslSource),
        isFalse,
        reason: 'mkcert must run without creating a console window',
      );
      expect(
        serviceSource,
        contains('runsDetachedExecutable('),
        reason: 'webservers must be launched detached via the shared policy',
      );
      expect(
        serviceSource,
        contains('BackgroundProcess.start('),
        reason: 'webservers must restart without creating a console window',
      );
    });
  });
}
