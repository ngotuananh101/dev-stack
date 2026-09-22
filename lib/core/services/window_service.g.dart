// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'window_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(WindowService)
final windowServiceProvider = WindowServiceProvider._();

final class WindowServiceProvider
    extends $AsyncNotifierProvider<WindowService, void> {
  WindowServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'windowServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$windowServiceHash();

  @$internal
  @override
  WindowService create() => WindowService();
}

String _$windowServiceHash() => r'399e8255134aa6cf297ba98997f48dbeffd22aa5';

abstract class _$WindowService extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
