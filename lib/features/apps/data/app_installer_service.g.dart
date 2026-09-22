// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_installer_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(appInstallerService)
final appInstallerServiceProvider = AppInstallerServiceProvider._();

final class AppInstallerServiceProvider
    extends
        $FunctionalProvider<
          AppInstallerService,
          AppInstallerService,
          AppInstallerService
        >
    with $Provider<AppInstallerService> {
  AppInstallerServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appInstallerServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appInstallerServiceHash();

  @$internal
  @override
  $ProviderElement<AppInstallerService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AppInstallerService create(Ref ref) {
    return appInstallerService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppInstallerService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppInstallerService>(value),
    );
  }
}

String _$appInstallerServiceHash() =>
    r'0570e774d61995b57c3e7e61c0ee78e36eb9ca36';
