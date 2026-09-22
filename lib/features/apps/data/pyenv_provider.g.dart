// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pyenv_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PyenvNotifier)
final pyenvNotifierProvider = PyenvNotifierProvider._();

final class PyenvNotifierProvider
    extends $AsyncNotifierProvider<PyenvNotifier, PyenvState> {
  PyenvNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pyenvNotifierProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pyenvNotifierHash();

  @$internal
  @override
  PyenvNotifier create() => PyenvNotifier();
}

String _$pyenvNotifierHash() => r'1c656cfd5d6a75d20a37265bdc703c20c7a943d4';

abstract class _$PyenvNotifier extends $AsyncNotifier<PyenvState> {
  FutureOr<PyenvState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<PyenvState>, PyenvState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<PyenvState>, PyenvState>,
              AsyncValue<PyenvState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
