// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'redis_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(Redis)
final redisProvider = RedisProvider._();

final class RedisProvider
    extends $AsyncNotifierProvider<Redis, List<RedisKey>> {
  RedisProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'redisProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$redisHash();

  @$internal
  @override
  Redis create() => Redis();
}

String _$redisHash() => r'932cacef34446d7e0442a9ddfc2083ce58d95fe8';

abstract class _$Redis extends $AsyncNotifier<List<RedisKey>> {
  FutureOr<List<RedisKey>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<RedisKey>>, List<RedisKey>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<RedisKey>>, List<RedisKey>>,
              AsyncValue<List<RedisKey>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(redisDbStats)
final redisDbStatsProvider = RedisDbStatsFamily._();

final class RedisDbStatsProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<int, int>>,
          Map<int, int>,
          FutureOr<Map<int, int>>
        >
    with $FutureModifier<Map<int, int>>, $FutureProvider<Map<int, int>> {
  RedisDbStatsProvider._({
    required RedisDbStatsFamily super.from,
    required AppModel super.argument,
  }) : super(
         retry: null,
         name: r'redisDbStatsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$redisDbStatsHash();

  @override
  String toString() {
    return r'redisDbStatsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Map<int, int>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<int, int>> create(Ref ref) {
    final argument = this.argument as AppModel;
    return redisDbStats(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is RedisDbStatsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$redisDbStatsHash() => r'adfbaae17669e2cff99dd17270285a4d080faab1';

final class RedisDbStatsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Map<int, int>>, AppModel> {
  RedisDbStatsFamily._()
    : super(
        retry: null,
        name: r'redisDbStatsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  RedisDbStatsProvider call(AppModel app) =>
      RedisDbStatsProvider._(argument: app, from: this);

  @override
  String toString() => r'redisDbStatsProvider';
}
