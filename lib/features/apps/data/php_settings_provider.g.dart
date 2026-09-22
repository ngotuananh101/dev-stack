// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'php_settings_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PhpSettings)
final phpSettingsProvider = PhpSettingsProvider._();

final class PhpSettingsProvider extends $NotifierProvider<PhpSettings, void> {
  PhpSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'phpSettingsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$phpSettingsHash();

  @$internal
  @override
  PhpSettings create() => PhpSettings();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$phpSettingsHash() => r'91b3f24c0ad0f2f14a27bdd011d10b394f1feb91';

abstract class _$PhpSettings extends $Notifier<void> {
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
