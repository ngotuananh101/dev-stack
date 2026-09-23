// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pyenv_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(Pyenv)
final pyenvProvider = PyenvProvider._();

final class PyenvProvider extends $AsyncNotifierProvider<Pyenv, PyenvState> {
  PyenvProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pyenvProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pyenvHash();

  @$internal
  @override
  Pyenv create() => Pyenv();
}

String _$pyenvHash() => r'0a9ea730425c9d04c9bdbd336ac3158c040c44ff';

abstract class _$Pyenv extends $AsyncNotifier<PyenvState> {
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
