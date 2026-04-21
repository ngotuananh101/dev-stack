// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'databases_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$installedDatabaseEnginesHash() =>
    r'b9b184affeb1907dd3b118b0fced721a00533522';

/// See also [installedDatabaseEngines].
@ProviderFor(installedDatabaseEngines)
final installedDatabaseEnginesProvider =
    AutoDisposeFutureProvider<List<AppModel>>.internal(
  installedDatabaseEngines,
  name: r'installedDatabaseEnginesProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$installedDatabaseEnginesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef InstalledDatabaseEnginesRef
    = AutoDisposeFutureProviderRef<List<AppModel>>;
String _$databasesNotifierHash() => r'b740d0a5791d1cb09ce96dfcc5946931058c1c54';

/// See also [DatabasesNotifier].
@ProviderFor(DatabasesNotifier)
final databasesNotifierProvider = AutoDisposeAsyncNotifierProvider<
    DatabasesNotifier, List<DatabaseRecord>>.internal(
  DatabasesNotifier.new,
  name: r'databasesNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$databasesNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$DatabasesNotifier = AutoDisposeAsyncNotifier<List<DatabaseRecord>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
