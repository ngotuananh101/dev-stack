// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'webserver_settings_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(WebserverSettings)
final webserverSettingsProvider = WebserverSettingsProvider._();

final class WebserverSettingsProvider
    extends $NotifierProvider<WebserverSettings, void> {
  WebserverSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'webserverSettingsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$webserverSettingsHash();

  @$internal
  @override
  WebserverSettings create() => WebserverSettings();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$webserverSettingsHash() => r'97f7ffbceb82c148696caeda4d4d41aa92c4ae38';

abstract class _$WebserverSettings extends $Notifier<void> {
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
