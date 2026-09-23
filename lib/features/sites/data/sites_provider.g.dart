// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sites_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(Sites)
final sitesProvider = SitesProvider._();

final class SitesProvider
    extends $AsyncNotifierProvider<Sites, List<SiteModel>> {
  SitesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sitesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sitesHash();

  @$internal
  @override
  Sites create() => Sites();
}

String _$sitesHash() => r'8a2ae773d56e0894ca6c06770349948f195ccf16';

abstract class _$Sites extends $AsyncNotifier<List<SiteModel>> {
  FutureOr<List<SiteModel>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<SiteModel>>, List<SiteModel>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<SiteModel>>, List<SiteModel>>,
              AsyncValue<List<SiteModel>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
