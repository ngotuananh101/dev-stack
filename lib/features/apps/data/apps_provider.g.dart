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
        isAutoDispose: true,
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

String _$appsRepositoryHash() => r'a8c9f29fef64b8e00c491d7f01238136458df61e';

@ProviderFor(AppsNotifier)
final appsNotifierProvider = AppsNotifierProvider._();

final class AppsNotifierProvider
    extends $AsyncNotifierProvider<AppsNotifier, List<AppModel>> {
  AppsNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appsNotifierProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appsNotifierHash();

  @$internal
  @override
  AppsNotifier create() => AppsNotifier();
}

String _$appsNotifierHash() => r'5dd8a544f142764fe1b451f53b3cf191747f5a3e';

abstract class _$AppsNotifier extends $AsyncNotifier<List<AppModel>> {
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
