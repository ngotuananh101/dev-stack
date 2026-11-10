/// Build metadata embedded at compile time through `--dart-define`.
///
/// Every value is optional: `flutter run` and plain `flutter build` carry no
/// metadata, and [fromValues] reports that as a development build instead of
/// inventing a timestamp or a commit.
class BuildInfo {
  static const String _missing = 'not set (development build)';

  final String? buildTime;
  final String? sha;
  final String? branch;
  final bool dirty;
  final String? frameworkVersion;
  final String? frameworkRevision;
  final String? engineRevision;
  final String? engineCommitDate;

  const BuildInfo({
    this.buildTime,
    this.sha,
    this.branch,
    this.dirty = false,
    this.frameworkVersion,
    this.frameworkRevision,
    this.engineRevision,
    this.engineCommitDate,
  });

  /// Reads the `--dart-define` keys written by `scripts/gen_build_info.dart`.
  factory BuildInfo.fromValues(Map<String, String> values) {
    String? read(String key) {
      final value = values[key]?.trim();
      return (value == null || value.isEmpty) ? null : value;
    }

    return BuildInfo(
      buildTime: read('BUILD_TIME'),
      sha: read('BUILD_SHA'),
      branch: read('BUILD_BRANCH'),
      dirty: read('BUILD_DIRTY') == 'true',
      frameworkVersion: read('FRAMEWORK_VERSION'),
      frameworkRevision: read('FRAMEWORK_REVISION'),
      engineRevision: read('ENGINE_REVISION'),
      engineCommitDate: read('ENGINE_COMMIT_DATE'),
    );
  }

  /// True when the binary was built by a packaging script.
  bool get isReleaseBuild => buildTime != null || sha != null;

  /// The UTC timestamp of the build, or a note that none was embedded.
  String get buildTimeLabel => buildTime ?? _missing;

  /// `<short sha> (<branch>, clean|dirty)`, or a note that none was embedded.
  String get shaLabel {
    if (sha == null) return _missing;
    return '$sha (${branch ?? 'unknown'}, ${dirty ? 'dirty' : 'clean'})';
  }

  /// `Flutter <version> (<os>) rev <revision>`, degrading to
  /// `Flutter (<os>)` when nothing was embedded and to
  /// `Flutter <version> (<os>)` when the revision is the only thing missing.
  String frameworkLabel(String operatingSystem) {
    final version = frameworkVersion;
    final revision = _short(frameworkRevision);
    if (version == null) return 'Flutter ($operatingSystem)';
    if (revision == null) return 'Flutter $version ($operatingSystem)';
    return 'Flutter $version ($operatingSystem) rev $revision';
  }

  /// `Flutter Engine rev <short revision> (<yyyy-MM-dd>)`. This is the real
  /// engine identity: Flutter engines carry no version number, only a git
  /// revision.
  String get engineLabel {
    final revision = _short(engineRevision);
    if (revision == null) return 'Flutter Engine (revision not embedded)';
    final date = _dateOnly(engineCommitDate);
    if (date == null) return 'Flutter Engine rev $revision';
    return 'Flutter Engine rev $revision ($date)';
  }

  /// First ten characters of a git revision, the length Flutter itself prints.
  static String? _short(String? revision) {
    if (revision == null || revision.isEmpty) return null;
    return revision.length <= 10 ? revision : revision.substring(0, 10);
  }

  /// The `yyyy-MM-dd` prefix of an ISO-8601 timestamp, or null.
  static String? _dateOnly(String? timestamp) {
    if (timestamp == null || timestamp.length < 10) return null;
    return timestamp.substring(0, 10);
  }
}
