// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hosts_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(HostsNotifier)
final hostsNotifierProvider = HostsNotifierProvider._();

final class HostsNotifierProvider
    extends $AsyncNotifierProvider<HostsNotifier, String> {
  HostsNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'hostsNotifierProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$hostsNotifierHash();

  @$internal
  @override
  HostsNotifier create() => HostsNotifier();
}

String _$hostsNotifierHash() => r'88fbfc736231694a3170e337802b8c19471e3b3d';

abstract class _$HostsNotifier extends $AsyncNotifier<String> {
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
