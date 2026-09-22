// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sites_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SitesNotifier)
final sitesNotifierProvider = SitesNotifierProvider._();

final class SitesNotifierProvider
    extends $AsyncNotifierProvider<SitesNotifier, List<SiteModel>> {
  SitesNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sitesNotifierProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sitesNotifierHash();

  @$internal
  @override
  SitesNotifier create() => SitesNotifier();
}

String _$sitesNotifierHash() => r'390dfecb8c85f5c2c09930084df9642b9a9a3ade';

abstract class _$SitesNotifier extends $AsyncNotifier<List<SiteModel>> {
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
