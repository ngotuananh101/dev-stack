import 'dart:io';

import 'package:dev_stack/core/database/isar_provider.dart';
import 'package:dev_stack/features/settings/data/settings_provider.dart';
import 'package:dev_stack/features/settings/domain/app_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

/// Locates the Isar native library shipped by `isar_plus_flutter_libs`.
///
/// `flutter test` does not link plugin natives, so `Isar.open` cannot resolve
/// the library on its own and throws `IsarNotReadyError`. The shared library is
/// in the pub cache; return null when it cannot be found so the test can skip
/// instead of failing on a machine without it.
String? _isarLibraryPath() {
  final libName = Platform.isWindows
      ? 'isar_plus.dll'
      : (Platform.isLinux ? 'libisar_plus.so' : null);
  if (libName == null) return null;

  final pubCache = Platform.environment['PUB_CACHE'] ??
      (Platform.isWindows
          ? '${Platform.environment['LOCALAPPDATA']}\\Pub\\Cache'
          : '${Platform.environment['HOME']}/.pub-cache');
  final hosted = Directory('$pubCache/hosted/pub.dev');
  if (!hosted.existsSync()) return null;

  for (final entry in hosted.listSync()) {
    if (entry is! Directory) continue;
    if (!entry.path.contains('isar_plus_flutter_libs-')) continue;
    final candidate = File(
      '${entry.path}/${Platform.isWindows ? 'windows' : 'linux'}/$libName',
    );
    if (candidate.existsSync()) return candidate.path;
  }
  return null;
}

void main() {
  late Isar isar;
  final libraryPath = _isarLibraryPath();

  setUp(() {
    final tempDir = Directory.systemTemp.createTempSync('devstack_settings_');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    Isar.initialize(libraryPath);
    isar = Isar.open(
      schemas: [AppSettingsSchema],
      directory: tempDir.path,
      name: 'settings_test_${DateTime.now().microsecondsSinceEpoch}',
    );
    addTearDown(isar.close);
  });

  ProviderContainer createContainer() => ProviderContainer.test(
    overrides: [isarProvider.overrideWith((ref) async => isar)],
  );

  group('Settings.updateField', () {
    test(
      'notifies listeners as soon as the value is written',
      () async {
        final container = createContainer();
        final initial = await container.read(settingsProvider.future);
        expect(initial.minimizeToTray, isFalse);

        final emitted = <AppSettings>[];
        container.listen(settingsProvider, (previous, next) {
          if (next.hasValue) emitted.add(next.value!);
        });

        await container
            .read(settingsProvider.notifier)
            .updateField(minimizeToTray: true);
        await container.pump();

        // `updateField` mutates the live Isar instance and re-emits that same
        // instance, so a value-equality filter on AsyncValue suppresses the
        // notification and the settings screen only refreshes on a remount.
        expect(
          emitted,
          hasLength(1),
          reason: 'toggling a switch must notify listeners immediately',
        );
        expect(emitted.single.minimizeToTray, isTrue);
      },
      skip: libraryPath == null ? 'Isar native library not available' : false,
    );

    test(
      'notifies for auto-start, the other switch on the same section',
      () async {
        final container = createContainer();
        await container.read(settingsProvider.future);

        final emitted = <AppSettings>[];
        container.listen(settingsProvider, (previous, next) {
          if (next.hasValue) emitted.add(next.value!);
        });

        // `launchAtStartup` has no plugin in tests, so the enable call is
        // swallowed by updateField's try/catch — the state write is what is
        // under test here.
        await container
            .read(settingsProvider.notifier)
            .updateField(autoStartWithWindows: true);
        await container.pump();

        expect(emitted, hasLength(1));
        expect(emitted.single.autoStartWithWindows, isTrue);
      },
      skip: libraryPath == null ? 'Isar native library not available' : false,
    );

    test(
      'persists the change so a later read sees it',
      () async {
        final container = createContainer();
        await container.read(settingsProvider.future);

        await container
            .read(settingsProvider.notifier)
            .updateField(minimizeToTray: true);

        final row = isar.appSettings.where().findFirst();
        expect(row?.minimizeToTray, isTrue);
      },
      skip: libraryPath == null ? 'Isar native library not available' : false,
    );
  });
}
