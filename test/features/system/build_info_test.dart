import 'package:flutter_test/flutter_test.dart';
import 'package:dev_stack/features/system/data/system_info_provider.dart';
import 'package:dev_stack/features/system/domain/build_info.dart';
import 'package:dev_stack/features/system/domain/system_info.dart';

const _fullBuildInfo = {
  'BUILD_TIME': '2026-11-10T07:12:44Z',
  'BUILD_SHA': '0ca2be6',
  'BUILD_BRANCH': 'main',
  'BUILD_DIRTY': 'false',
  'FRAMEWORK_VERSION': '3.47.9',
  'FRAMEWORK_REVISION': 'c197ca5199e9ee5661e865596c9c07294dfab51c',
  'ENGINE_REVISION': '89c39edfdfae2949f6806e4a315c0c08522238b7',
  'ENGINE_COMMIT_DATE': '2026-10-27 19:51:20.000Z',
};

void main() {
  group('BuildInfo.fromValues', () {
    test('absent metadata reports a development build', () {
      final info = BuildInfo.fromValues(const {});

      expect(info.buildTimeLabel, 'not set (development build)');
      expect(info.shaLabel, 'not set (development build)');
      expect(info.frameworkLabel('Linux'), 'Flutter (Linux)');
      expect(info.engineLabel, 'Flutter Engine (revision not embedded)');
      expect(info.isReleaseBuild, isFalse);
    });

    test('embedded metadata is reported verbatim', () {
      final info = BuildInfo.fromValues(_fullBuildInfo);

      expect(info.buildTimeLabel, '2026-11-10T07:12:44Z');
      expect(info.shaLabel, '0ca2be6 (main, clean)');
      expect(info.frameworkLabel('Linux'), 'Flutter 3.47.9 (Linux) rev c197ca5199');
      expect(info.engineLabel, 'Flutter Engine rev 89c39edfdf (2026-10-27)');
      expect(info.isReleaseBuild, isTrue);
    });

    test('a dirty worktree is called out', () {
      final info = BuildInfo.fromValues({..._fullBuildInfo, 'BUILD_DIRTY': 'true'});

      expect(info.shaLabel, '0ca2be6 (main, dirty)');
    });

    test('an engine revision without a date still reports the revision', () {
      final info = BuildInfo.fromValues({
        'ENGINE_REVISION': '89c39edfdfae2949f6806e4a315c0c08522238b7',
      });

      expect(info.engineLabel, 'Flutter Engine rev 89c39edfdf');
    });

    test('a framework version without a revision omits the rev suffix', () {
      final info = BuildInfo.fromValues({'FRAMEWORK_VERSION': '3.47.9'});

      expect(info.frameworkLabel('Windows'), 'Flutter 3.47.9 (Windows)');
    });

    test('a sha without a branch and a clean tree omits the branch name', () {
      final info = BuildInfo.fromValues({'BUILD_SHA': '0ca2be6', 'BUILD_DIRTY': 'false'});

      expect(info.shaLabel, '0ca2be6 (unknown, clean)');
    });
  });

  group('SystemInfoState.resolveAppPath', () {
    test('uses the directory holding the native executable', () {
      expect(
        SystemInfoState.resolveAppPath(resolvedExecutable: '/opt/dev-stack/dev_stack'),
        '/opt/dev-stack',
      );
    });

    test('splits Windows paths with the Windows separator', () {
      expect(
        SystemInfoState.resolveAppPath(
          resolvedExecutable: r'C:\Ponta\dev_stack.exe',
          isWindows: true,
        ),
        r'C:\Ponta',
      );
    });

    test('prefers the AppImage file over its ephemeral mount point', () {
      expect(
        SystemInfoState.resolveAppPath(
          resolvedExecutable: '/tmp/.mount_DevStaXk9zQ/dev_stack',
          appImage: '/home/anhnt/Apps/Ponta-DevStack.AppImage',
        ),
        '/home/anhnt/Apps',
      );
    });
  });

  group('SystemInfo.toFormattedString', () {
    SystemInfo sample(BuildInfo buildInfo) => SystemInfo(
      rawOutput: 'raw platform output',
      buildInfo: buildInfo,
      appVersion: '1.2.0+3',
      frameworkVersion: buildInfo.frameworkLabel('Linux'),
      dartVersion: '3.13.7',
      databaseVersion: 'isar_plus 1.3.9',
      engineVersion: buildInfo.engineLabel,
      appPath: '/opt/dev-stack',
      userDataPath: '/home/anhnt/.ponta',
      generatedAt: DateTime.utc(2026, 11, 10, 7, 30),
    );

    test('renders a packaged build with its timestamp and commit', () {
      final text = sample(BuildInfo.fromValues(_fullBuildInfo)).toFormattedString();

      expect(text, contains('[BUILD]'));
      expect(text, contains('Build Time          : 2026-11-10T07:12:44Z'));
      expect(text, contains('Build SHA           : 0ca2be6 (main, clean)'));
      expect(text, contains('Framework           : Flutter 3.47.9 (Linux) rev c197ca5199'));
      expect(text, contains('Database            : isar_plus 1.3.9'));
      expect(text, contains('Engine              : Flutter Engine rev 89c39edfdf (2026-10-27)'));
    });

    test('renders a development build without pretending to have metadata', () {
      final text = sample(BuildInfo.fromValues(const {})).toFormattedString();

      expect(text, contains('Build Time          : not set (development build)'));
      expect(text, contains('Build SHA           : not set (development build)'));
      expect(text, isNot(contains('Chromium')));
    });
  });
}
