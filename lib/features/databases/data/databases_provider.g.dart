// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'databases_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(DatabasesNotifier)
final databasesNotifierProvider = DatabasesNotifierProvider._();

final class DatabasesNotifierProvider
    extends $AsyncNotifierProvider<DatabasesNotifier, List<DatabaseRecord>> {
  DatabasesNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'databasesNotifierProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$databasesNotifierHash();

  @$internal
  @override
  DatabasesNotifier create() => DatabasesNotifier();
}

String _$databasesNotifierHash() => r'3dc1fea7378efbe450b18e71e88a426169b482b0';

abstract class _$DatabasesNotifier
    extends $AsyncNotifier<List<DatabaseRecord>> {
  FutureOr<List<DatabaseRecord>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<List<DatabaseRecord>>, List<DatabaseRecord>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<DatabaseRecord>>,
                List<DatabaseRecord>
              >,
              AsyncValue<List<DatabaseRecord>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(installedDatabaseEngines)
final installedDatabaseEnginesProvider = InstalledDatabaseEnginesProvider._();

final class InstalledDatabaseEnginesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<AppModel>>,
          List<AppModel>,
          FutureOr<List<AppModel>>
        >
    with $FutureModifier<List<AppModel>>, $FutureProvider<List<AppModel>> {
  InstalledDatabaseEnginesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'installedDatabaseEnginesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$installedDatabaseEnginesHash();

  @$internal
  @override
  $FutureProviderElement<List<AppModel>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<AppModel>> create(Ref ref) {
    return installedDatabaseEngines(ref);
  }
}

String _$installedDatabaseEnginesHash() =>
    r'b9b184affeb1907dd3b118b0fced721a00533522';
