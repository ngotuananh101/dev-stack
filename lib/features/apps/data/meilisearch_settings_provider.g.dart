// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meilisearch_settings_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(MeilisearchSettings)
final meilisearchSettingsProvider = MeilisearchSettingsProvider._();

final class MeilisearchSettingsProvider
    extends $NotifierProvider<MeilisearchSettings, void> {
  MeilisearchSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'meilisearchSettingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$meilisearchSettingsHash();

  @$internal
  @override
  MeilisearchSettings create() => MeilisearchSettings();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$meilisearchSettingsHash() =>
    r'27a860ff09c6ac62890f049e49202dcf859ab132';

abstract class _$MeilisearchSettings extends $Notifier<void> {
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
