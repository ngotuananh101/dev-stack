// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hosts_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(Hosts)
final hostsProvider = HostsProvider._();

final class HostsProvider extends $AsyncNotifierProvider<Hosts, String> {
  HostsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'hostsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$hostsHash();

  @$internal
  @override
  Hosts create() => Hosts();
}

String _$hostsHash() => r'0061757b65c423bc7ae0c3a48f62ea6e3b2b6322';

abstract class _$Hosts extends $AsyncNotifier<String> {
  FutureOr<String> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<String>, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<String>, String>,
              AsyncValue<String>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
