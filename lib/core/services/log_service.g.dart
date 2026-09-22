// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'log_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(logService)
final logServiceProvider = LogServiceProvider._();

final class LogServiceProvider
    extends $FunctionalProvider<LogService, LogService, LogService>
    with $Provider<LogService> {
  LogServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'logServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$logServiceHash();

  @$internal
  @override
  $ProviderElement<LogService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LogService create(Ref ref) {
    return logService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LogService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LogService>(value),
    );
  }
}

String _$logServiceHash() => r'9d0779ba28c102b4f571bb367267ed734ea691e8';
