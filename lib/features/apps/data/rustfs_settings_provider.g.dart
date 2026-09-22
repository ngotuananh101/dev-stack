// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rustfs_settings_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(RustFSSettings)
final rustFSSettingsProvider = RustFSSettingsProvider._();

final class RustFSSettingsProvider
    extends $NotifierProvider<RustFSSettings, void> {
  RustFSSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'rustFSSettingsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$rustFSSettingsHash();

  @$internal
  @override
  RustFSSettings create() => RustFSSettings();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$rustFSSettingsHash() => r'4c9e52b88583ccb6b481992f01745ca518102a7a';

abstract class _$RustFSSettings extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
