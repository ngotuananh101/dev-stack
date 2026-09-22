// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'error_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AppError)
final appErrorProvider = AppErrorProvider._();

final class AppErrorProvider extends $NotifierProvider<AppError, String?> {
  AppErrorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appErrorProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appErrorHash();

  @$internal
  @override
  AppError create() => AppError();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$appErrorHash() => r'82c1d49533a66feced646952d6a2a0a297f9f7cb';

abstract class _$AppError extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
