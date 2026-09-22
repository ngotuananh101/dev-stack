// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'system_info_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SystemInfoNotifier)
final systemInfoNotifierProvider = SystemInfoNotifierProvider._();

final class SystemInfoNotifierProvider
    extends $AsyncNotifierProvider<SystemInfoNotifier, SystemInfo> {
  SystemInfoNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'systemInfoNotifierProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$systemInfoNotifierHash();

  @$internal
  @override
  SystemInfoNotifier create() => SystemInfoNotifier();
}

String _$systemInfoNotifierHash() =>
    r'494ac9e0ad9d5e29e67f41d73984d713513c414d';

abstract class _$SystemInfoNotifier extends $AsyncNotifier<SystemInfo> {
  FutureOr<SystemInfo> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<SystemInfo>, SystemInfo>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<SystemInfo>, SystemInfo>,
              AsyncValue<SystemInfo>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
