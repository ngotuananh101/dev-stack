// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_service_manager.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(appServiceManager)
final appServiceManagerProvider = AppServiceManagerProvider._();

final class AppServiceManagerProvider
    extends
        $FunctionalProvider<
          AppServiceManager,
          AppServiceManager,
          AppServiceManager
        >
    with $Provider<AppServiceManager> {
  AppServiceManagerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appServiceManagerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appServiceManagerHash();

  @$internal
  @override
  $ProviderElement<AppServiceManager> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AppServiceManager create(Ref ref) {
    return appServiceManager(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppServiceManager value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppServiceManager>(value),
    );
  }
}

String _$appServiceManagerHash() => r'02984aa269a59c61e4a51e72fa6b0aff9bb360e0';
