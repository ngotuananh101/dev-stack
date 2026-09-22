// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'path_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(pathService)
final pathServiceProvider = PathServiceProvider._();

final class PathServiceProvider
    extends $FunctionalProvider<PathService, PathService, PathService>
    with $Provider<PathService> {
  PathServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pathServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pathServiceHash();

  @$internal
  @override
  $ProviderElement<PathService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PathService create(Ref ref) {
    return pathService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PathService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PathService>(value),
    );
  }
}

String _$pathServiceHash() => r'361905b8f9eb32e074735a15f146f1dc4eb13bbd';
