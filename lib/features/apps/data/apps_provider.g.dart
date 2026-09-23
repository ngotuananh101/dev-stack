// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'apps_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(appsRepository)
final appsRepositoryProvider = AppsRepositoryProvider._();

final class AppsRepositoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<AppsRepository>,
          AppsRepository,
          FutureOr<AppsRepository>
        >
    with $FutureModifier<AppsRepository>, $FutureProvider<AppsRepository> {
  AppsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appsRepositoryHash();

  @$internal
  @override
  $FutureProviderElement<AppsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<AppsRepository> create(Ref ref) {
    return appsRepository(ref);
  }
}

String _$appsRepositoryHash() => r'cf51f07648ee18ce26cf8c9d3b5b40349421ca69';

@ProviderFor(Apps)
final appsProvider = AppsProvider._();

final class AppsProvider extends $AsyncNotifierProvider<Apps, List<AppModel>> {
  AppsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appsHash();

  @$internal
  @override
  Apps create() => Apps();
}

String _$appsHash() => r'ae9246a9be34e0aa7dc194f30abc4ea295816cd7';

abstract class _$Apps extends $AsyncNotifier<List<AppModel>> {
  FutureOr<List<AppModel>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<AppModel>>, List<AppModel>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<AppModel>>, List<AppModel>>,
              AsyncValue<List<AppModel>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
