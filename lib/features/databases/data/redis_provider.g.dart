// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'redis_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$redisDbStatsHash() => r'adfbaae17669e2cff99dd17270285a4d080faab1';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// See also [redisDbStats].
@ProviderFor(redisDbStats)
const redisDbStatsProvider = RedisDbStatsFamily();

/// See also [redisDbStats].
class RedisDbStatsFamily extends Family<AsyncValue<Map<int, int>>> {
  /// See also [redisDbStats].
  const RedisDbStatsFamily();

  /// See also [redisDbStats].
  RedisDbStatsProvider call(
    AppModel app,
  ) {
    return RedisDbStatsProvider(
      app,
    );
  }

  @override
  RedisDbStatsProvider getProviderOverride(
    covariant RedisDbStatsProvider provider,
  ) {
    return call(
      provider.app,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'redisDbStatsProvider';
}

/// See also [redisDbStats].
class RedisDbStatsProvider extends AutoDisposeFutureProvider<Map<int, int>> {
  /// See also [redisDbStats].
  RedisDbStatsProvider(
    AppModel app,
  ) : this._internal(
          (ref) => redisDbStats(
            ref as RedisDbStatsRef,
            app,
          ),
          from: redisDbStatsProvider,
          name: r'redisDbStatsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$redisDbStatsHash,
          dependencies: RedisDbStatsFamily._dependencies,
          allTransitiveDependencies:
              RedisDbStatsFamily._allTransitiveDependencies,
          app: app,
        );

  RedisDbStatsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.app,
  }) : super.internal();

  final AppModel app;

  @override
  Override overrideWith(
    FutureOr<Map<int, int>> Function(RedisDbStatsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: RedisDbStatsProvider._internal(
        (ref) => create(ref as RedisDbStatsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        app: app,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<Map<int, int>> createElement() {
    return _RedisDbStatsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is RedisDbStatsProvider && other.app == app;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, app.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin RedisDbStatsRef on AutoDisposeFutureProviderRef<Map<int, int>> {
  /// The parameter `app` of this provider.
  AppModel get app;
}

class _RedisDbStatsProviderElement
    extends AutoDisposeFutureProviderElement<Map<int, int>>
    with RedisDbStatsRef {
  _RedisDbStatsProviderElement(super.provider);

  @override
  AppModel get app => (origin as RedisDbStatsProvider).app;
}

String _$redisNotifierHash() => r'c414e47f9e64ca021896723329d3018da8da9d68';

/// See also [RedisNotifier].
@ProviderFor(RedisNotifier)
final redisNotifierProvider =
    AutoDisposeAsyncNotifierProvider<RedisNotifier, List<RedisKey>>.internal(
  RedisNotifier.new,
  name: r'redisNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$redisNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$RedisNotifier = AutoDisposeAsyncNotifier<List<RedisKey>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
