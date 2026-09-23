// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'databases_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(Databases)
final databasesProvider = DatabasesProvider._();

final class DatabasesProvider
    extends $AsyncNotifierProvider<Databases, List<DatabaseRecord>> {
  DatabasesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'databasesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$databasesHash();

  @$internal
  @override
  Databases create() => Databases();
}

String _$databasesHash() => r'c776b7bae1d2def85ec01229202d11ccf3837374';

abstract class _$Databases extends $AsyncNotifier<List<DatabaseRecord>> {
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
    r'10c29d527ba19907fd713b21f5556286796fb8ef';
