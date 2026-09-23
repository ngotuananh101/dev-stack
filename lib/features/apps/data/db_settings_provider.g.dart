// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'db_settings_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(DbSettings)
final dbSettingsProvider = DbSettingsProvider._();

final class DbSettingsProvider extends $NotifierProvider<DbSettings, void> {
  DbSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dbSettingsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dbSettingsHash();

  @$internal
  @override
  DbSettings create() => DbSettings();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$dbSettingsHash() => r'93716f93093e10976de8cf00417522b93f4108a3';

abstract class _$DbSettings extends $Notifier<void> {
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
