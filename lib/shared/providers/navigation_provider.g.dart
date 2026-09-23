// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'navigation_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(Navigation)
final navigationProvider = NavigationProvider._();

final class NavigationProvider
    extends $NotifierProvider<Navigation, NavigationTab> {
  NavigationProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'navigationProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$navigationHash();

  @$internal
  @override
  Navigation create() => Navigation();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NavigationTab value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NavigationTab>(value),
    );
  }
}

String _$navigationHash() => r'0569a27b1ca7d32e986432261514224c3ec3eb94';

abstract class _$Navigation extends $Notifier<NavigationTab> {
  NavigationTab build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<NavigationTab, NavigationTab>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<NavigationTab, NavigationTab>,
              NavigationTab,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
