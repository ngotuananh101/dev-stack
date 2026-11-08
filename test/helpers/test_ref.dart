import 'package:dev_stack/features/settings/data/settings_provider.dart';
import 'package:dev_stack/features/settings/domain/app_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class _DefaultTestSettingsNotifier extends Settings {
  final AppSettings? _settings;
  _DefaultTestSettingsNotifier([this._settings]);

  @override
  Future<AppSettings> build() {
    final s = _settings ?? AppSettings();
    state = AsyncData(s);
    return Future.value(s);
  }
}

/// A container that lives for the whole test process, used only to hand out a
/// real [Ref] via [testRef].
final ProviderContainer _refContainer = ProviderContainer(
  overrides: [
    settingsProvider.overrideWith(() => _DefaultTestSettingsNotifier()),
  ],
);

final Provider<Ref> _refProbe = Provider<Ref>((ref) => ref);

/// Returns a real [Ref] for tests.
///
/// Riverpod 3 sealed the [Ref] class, so the previous
/// `class _FakeRef implements Ref` trick no longer compiles. Several services
/// (e.g. `AppInstallerService`) take a [Ref] in their constructor.
///
/// The returned [Ref] belongs to a process-wide [ProviderContainer] that is
/// never disposed, which keeps it valid for the lifetime of the test run.
Ref testRef([ProviderContainer? container]) =>
    (container ?? _refContainer).read(_refProbe);

/// Helper to create a container with custom settings for tests.
ProviderContainer createTestRefContainer({AppSettings? settings}) {
  return ProviderContainer(
    overrides: [
      settingsProvider.overrideWith(
        () => _DefaultTestSettingsNotifier(settings),
      ),
    ],
  );
}
