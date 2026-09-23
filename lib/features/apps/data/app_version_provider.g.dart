// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_version_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AppVersions)
final appVersionsProvider = AppVersionsFamily._();

final class AppVersionsProvider
    extends $AsyncNotifierProvider<AppVersions, AppVersionInfo> {
  AppVersionsProvider._({
    required AppVersionsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'appVersionsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$appVersionsHash();

  @override
  String toString() {
    return r'appVersionsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  AppVersions create() => AppVersions();

  @override
  bool operator ==(Object other) {
    return other is AppVersionsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$appVersionsHash() => r'362fad6356dc36b4f610337347b95325dd8c7fb8';

final class AppVersionsFamily extends $Family
    with
        $ClassFamilyOverride<
          AppVersions,
          AsyncValue<AppVersionInfo>,
          AppVersionInfo,
          FutureOr<AppVersionInfo>,
          String
        > {
  AppVersionsFamily._()
    : super(
        retry: null,
        name: r'appVersionsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AppVersionsProvider call(String appId) =>
      AppVersionsProvider._(argument: appId, from: this);

  @override
  String toString() => r'appVersionsProvider';
}

abstract class _$AppVersions extends $AsyncNotifier<AppVersionInfo> {
  late final _$args = ref.$arg as String;
  String get appId => _$args;

  FutureOr<AppVersionInfo> build(String appId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<AppVersionInfo>, AppVersionInfo>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<AppVersionInfo>, AppVersionInfo>,
              AsyncValue<AppVersionInfo>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
