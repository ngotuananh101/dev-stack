// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sidebar_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether the navigation sidebar is collapsed to its icon-only width.
///
/// A narrow window leaves the main content very little room while the sidebar
/// still holds its full 240px, so the user can fold it away to 64px.

@ProviderFor(SidebarCollapsed)
final sidebarCollapsedProvider = SidebarCollapsedProvider._();

/// Whether the navigation sidebar is collapsed to its icon-only width.
///
/// A narrow window leaves the main content very little room while the sidebar
/// still holds its full 240px, so the user can fold it away to 64px.
final class SidebarCollapsedProvider
    extends $NotifierProvider<SidebarCollapsed, bool> {
  /// Whether the navigation sidebar is collapsed to its icon-only width.
  ///
  /// A narrow window leaves the main content very little room while the sidebar
  /// still holds its full 240px, so the user can fold it away to 64px.
  SidebarCollapsedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sidebarCollapsedProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sidebarCollapsedHash();

  @$internal
  @override
  SidebarCollapsed create() => SidebarCollapsed();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$sidebarCollapsedHash() => r'c4517adc7df6880e9adc9bcd7371ccbc36a082be';

/// Whether the navigation sidebar is collapsed to its icon-only width.
///
/// A narrow window leaves the main content very little room while the sidebar
/// still holds its full 240px, so the user can fold it away to 64px.

abstract class _$SidebarCollapsed extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
