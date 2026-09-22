// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'system_info_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SystemInfoState)
final systemInfoStateProvider = SystemInfoStateProvider._();

final class SystemInfoStateProvider
    extends $AsyncNotifierProvider<SystemInfoState, SystemInfo> {
  SystemInfoStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'systemInfoStateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$systemInfoStateHash();

  @$internal
  @override
  SystemInfoState create() => SystemInfoState();
}

String _$systemInfoStateHash() => r'a9b8c42e2a5b6dca184ea11728b7fb809e5f1d1d';

abstract class _$SystemInfoState extends $AsyncNotifier<SystemInfo> {
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
