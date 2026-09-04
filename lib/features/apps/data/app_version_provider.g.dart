// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_version_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$appVersionsHash() => r'3f562005c57d6296f89ffad586a8b9c178219ad9';

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

abstract class _$AppVersions
    extends BuildlessAutoDisposeAsyncNotifier<AppVersionInfo> {
  late final String appId;

  Future<AppVersionInfo> build(
    String appId,
  );
}

/// See also [AppVersions].
@ProviderFor(AppVersions)
const appVersionsProvider = AppVersionsFamily();

/// See also [AppVersions].
class AppVersionsFamily extends Family<AsyncValue<AppVersionInfo>> {
  /// See also [AppVersions].
  const AppVersionsFamily();

  /// See also [AppVersions].
  AppVersionsProvider call(
    String appId,
  ) {
    return AppVersionsProvider(
      appId,
    );
  }

  @override
  AppVersionsProvider getProviderOverride(
    covariant AppVersionsProvider provider,
  ) {
    return call(
      provider.appId,
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
  String? get name => r'appVersionsProvider';
}

/// See also [AppVersions].
class AppVersionsProvider
    extends AutoDisposeAsyncNotifierProviderImpl<AppVersions, AppVersionInfo> {
  /// See also [AppVersions].
  AppVersionsProvider(
    String appId,
  ) : this._internal(
          () => AppVersions()..appId = appId,
          from: appVersionsProvider,
          name: r'appVersionsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$appVersionsHash,
          dependencies: AppVersionsFamily._dependencies,
          allTransitiveDependencies:
              AppVersionsFamily._allTransitiveDependencies,
          appId: appId,
        );

  AppVersionsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.appId,
  }) : super.internal();

  final String appId;

  @override
  Future<AppVersionInfo> runNotifierBuild(
    covariant AppVersions notifier,
  ) {
    return notifier.build(
      appId,
    );
  }

  @override
  Override overrideWith(AppVersions Function() create) {
    return ProviderOverride(
      origin: this,
      override: AppVersionsProvider._internal(
        () => create()..appId = appId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        appId: appId,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<AppVersions, AppVersionInfo>
      createElement() {
    return _AppVersionsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is AppVersionsProvider && other.appId == appId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, appId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin AppVersionsRef on AutoDisposeAsyncNotifierProviderRef<AppVersionInfo> {
  /// The parameter `appId` of this provider.
  String get appId;
}

class _AppVersionsProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<AppVersions, AppVersionInfo>
    with AppVersionsRef {
  _AppVersionsProviderElement(super.provider);

  @override
  String get appId => (origin as AppVersionsProvider).appId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
