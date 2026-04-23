// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'apps_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$appsRepositoryHash() => r'a8c9f29fef64b8e00c491d7f01238136458df61e';

/// See also [appsRepository].
@ProviderFor(appsRepository)
final appsRepositoryProvider =
    AutoDisposeFutureProvider<AppsRepository>.internal(
  appsRepository,
  name: r'appsRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$appsRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef AppsRepositoryRef = AutoDisposeFutureProviderRef<AppsRepository>;
String _$appsNotifierHash() => r'9bba39e45f5dac2efa393f008b840d64b660fde3';

/// See also [AppsNotifier].
@ProviderFor(AppsNotifier)
final appsNotifierProvider =
    AutoDisposeAsyncNotifierProvider<AppsNotifier, List<AppModel>>.internal(
  AppsNotifier.new,
  name: r'appsNotifierProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$appsNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$AppsNotifier = AutoDisposeAsyncNotifier<List<AppModel>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
