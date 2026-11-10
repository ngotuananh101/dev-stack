// Writes .dart_tool/build_info.json, which the packaging scripts feed to
// `flutter build --dart-define-from-file`.
//
// Run from the repository root: `dart run scripts/gen_build_info.dart`.
// Nothing here is committed: the file describes one build, not the source.

import 'dart:convert';
import 'dart:io';

const _outputPath = '.dart_tool/build_info.json';

Future<void> main() async {
  final framework = await _frameworkInfo();
  final info = <String, String>{
    'BUILD_TIME': DateTime.now().toUtc().toIso8601String(),
    'BUILD_SHA': await _git(['rev-parse', '--short', 'HEAD']) ?? 'unknown',
    'BUILD_BRANCH': await _git(['rev-parse', '--abbrev-ref', 'HEAD']) ?? 'unknown',
    'BUILD_DIRTY': await _isDirty() ? 'true' : 'false',
    'FRAMEWORK_VERSION': framework?.frameworkVersion ?? '',
    'FRAMEWORK_REVISION': framework?.frameworkRevision ?? '',
    'ENGINE_REVISION': framework?.engineRevision ?? '',
    'ENGINE_COMMIT_DATE': framework?.engineCommitDate ?? '',
  };

  final file = File(_outputPath);
  await file.parent.create(recursive: true);
  await file.writeAsString('${const JsonEncoder.withIndent('  ').convert(info)}\n');

  stdout.writeln('Wrote $_outputPath:');
  for (final entry in info.entries) {
    stdout.writeln('  ${entry.key.padRight(20)} ${entry.value}');
  }
}

/// Fields of `flutter --version --machine` this script needs.
class _FrameworkInfo {
  final String? frameworkVersion;
  final String? frameworkRevision;
  final String? engineRevision;
  final String? engineCommitDate;

  _FrameworkInfo(Map<String, dynamic> json)
    : frameworkVersion = json['frameworkVersion'] as String?,
      frameworkRevision = json['frameworkRevision'] as String?,
      engineRevision = json['engineRevision'] as String?,
      engineCommitDate = json['engineCommitDate'] as String?;
}

/// Resolves the Flutter SDK that will perform the build. A missing or broken
/// `flutter` is not fatal: the metadata simply stays empty and the app reports
/// that the revision was not embedded.
Future<_FrameworkInfo?> _frameworkInfo() async {
  try {
    final result = await Process.run('flutter', ['--version', '--machine']);
    if (result.exitCode != 0) return null;
    final decoded = jsonDecode(result.stdout as String);
    if (decoded is! Map<String, dynamic>) return null;
    return _FrameworkInfo(decoded);
  } on ProcessException {
    stderr.writeln('warning: flutter not found; framework/engine metadata left empty');
    return null;
  } on FormatException {
    stderr.writeln('warning: could not parse flutter --version --machine output');
    return null;
  }
}

/// The stdout of a git command, or null when git is unavailable or the
/// directory is not a repository.
Future<String?> _git(List<String> args) async {
  try {
    final result = await Process.run('git', args);
    if (result.exitCode != 0) return null;
    final out = (result.stdout as String).trim();
    return out.isEmpty ? null : out;
  } on ProcessException {
    return null;
  }
}

/// True when tracked files differ from HEAD, ignoring the untracked build
/// output that every local build leaves behind.
Future<bool> _isDirty() async {
  final status = await _git(['status', '--porcelain', '--untracked-files=no']);
  return status != null;
}
