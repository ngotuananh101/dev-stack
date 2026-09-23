// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mongodb_settings_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(MongodbSettings)
final mongodbSettingsProvider = MongodbSettingsProvider._();

final class MongodbSettingsProvider
    extends $NotifierProvider<MongodbSettings, void> {
  MongodbSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mongodbSettingsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mongodbSettingsHash();

  @$internal
  @override
  MongodbSettings create() => MongodbSettings();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$mongodbSettingsHash() => r'3e459b9e60e4fd122dd8a3c3376c9a5c877d2255';

abstract class _$MongodbSettings extends $Notifier<void> {
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
