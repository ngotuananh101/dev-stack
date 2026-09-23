// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ssl_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SslService)
final sslServiceProvider = SslServiceProvider._();

final class SslServiceProvider
    extends $AsyncNotifierProvider<SslService, bool> {
  SslServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sslServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sslServiceHash();

  @$internal
  @override
  SslService create() => SslService();
}

String _$sslServiceHash() => r'2750609d532c3499566db1749b2842d47c1095ae';

abstract class _$SslService extends $AsyncNotifier<bool> {
  FutureOr<bool> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<bool>, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<bool>, bool>,
              AsyncValue<bool>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
