// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'redis_settings_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(RedisSettings)
final redisSettingsProvider = RedisSettingsProvider._();

final class RedisSettingsProvider
    extends $NotifierProvider<RedisSettings, void> {
  RedisSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'redisSettingsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$redisSettingsHash();

  @$internal
  @override
  RedisSettings create() => RedisSettings();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$redisSettingsHash() => r'1cbfa041ada9b9fa4743a32a383ddbd798a3e082';

abstract class _$RedisSettings extends $Notifier<void> {
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
