import 'package:dev_stack/core/services/log_service.dart';
import 'package:dev_stack/core/services/path_service.dart';
import 'package:dev_stack/features/apps/data/app_installer_service.dart';
import 'package:dev_stack/features/apps/data/meilisearch_settings_provider.dart';
import 'package:dev_stack/features/apps/data/rustfs_settings_provider.dart';
import 'package:dev_stack/shared/providers/error_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The apps state graph is read by `WindowService`, which is `keepAlive`, so its
/// dependencies have to be `keepAlive` too — otherwise
/// `only_use_keep_alive_inside_keep_alive` fires, correctly reporting that a
/// long-lived provider is reaching into short-lived state.
///
/// Each case listens to the provider, closes the subscription, and asserts the
/// provider is still alive. An autoDispose provider would have been released by
/// then.
///
/// The provider itself and the liveness check are both passed in as closures:
/// `ProviderBase` — the parameter type `ProviderContainer.exists` takes — is not
/// exported from `flutter_riverpod.dart`, so a helper cannot name it.
Future<void> expectKeptAlive(
  ProviderContainer container,
  ProviderSubscription<Object?> subscription,
  bool Function() isAlive,
) async {
  await container.pump();
  subscription.close();
  await container.pump();
  expect(isAlive(), isTrue);
}

void main() {
  test('logServiceProvider stays alive', () async {
    final container = ProviderContainer.test();
    await expectKeptAlive(
      container,
      container.listen(logServiceProvider, (previous, next) {}),
      () => container.exists(logServiceProvider),
    );
  });

  test('appErrorProvider stays alive', () async {
    final container = ProviderContainer.test();
    await expectKeptAlive(
      container,
      container.listen(appErrorProvider, (previous, next) {}),
      () => container.exists(appErrorProvider),
    );
  });

  test('pathServiceProvider stays alive', () async {
    final container = ProviderContainer.test();
    await expectKeptAlive(
      container,
      container.listen(pathServiceProvider, (previous, next) {}),
      () => container.exists(pathServiceProvider),
    );
  });

  test('appInstallerServiceProvider stays alive', () async {
    final container = ProviderContainer.test();
    await expectKeptAlive(
      container,
      container.listen(appInstallerServiceProvider, (previous, next) {}),
      () => container.exists(appInstallerServiceProvider),
    );
  });

  test('meilisearchSettingsProvider stays alive', () async {
    final container = ProviderContainer.test();
    await expectKeptAlive(
      container,
      container.listen(meilisearchSettingsProvider, (previous, next) {}),
      () => container.exists(meilisearchSettingsProvider),
    );
  });

  test('rustFSSettingsProvider stays alive', () async {
    final container = ProviderContainer.test();
    await expectKeptAlive(
      container,
      container.listen(rustFSSettingsProvider, (previous, next) {}),
      () => container.exists(rustFSSettingsProvider),
    );
  });
}
