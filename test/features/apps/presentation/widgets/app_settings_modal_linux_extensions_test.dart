import 'dart:async';

import 'package:dev_stack/features/apps/data/apps_provider.dart';
import 'package:dev_stack/features/apps/data/php_settings_provider.dart';
import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:dev_stack/features/apps/presentation/widgets/app_settings_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _StaticAppsNotifier extends Apps {
  @override
  Future<List<AppModel>> build() => Future.value([]);
}

/// Stands in for the real provider. [toggleGate] lets a test hold a toggle
/// in flight so the busy state can be observed.
class _MockPhpSettings extends PhpSettings {
  final List<PhpExtension> _exts;
  final Completer<void>? _toggleGate;

  _MockPhpSettings(this._exts, {Completer<void>? toggleGate})
    : _toggleGate = toggleGate;

  @override
  Future<List<PhpExtension>> getExtensions(
    AppModel app, [
    String? iniContent,
  ]) async => _exts;

  @override
  Future<String?> toggleExtension(
    AppModel app,
    PhpExtension ext,
    bool enable,
  ) async {
    if (_toggleGate != null) await _toggleGate.future;
    return 'Extension ${ext.name} ${enable ? 'enabled' : 'disabled'}.';
  }
}

AppModel _phpApp() => AppModel(
  appId: 'php85',
  name: 'PHP 8.5',
  categories: ['runtime'],
  groupName: 'php',
  versions: ['8.5.0'],
  location: 'system_package',
  isInstalled: true,
  installedVersion: '8.5.0',
  execFilePath: '/usr/sbin/php-fpm8.5',
);

const _curl = PhpExtension(
  name: 'curl',
  fileName: 'curl.so',
  isEnabled: true,
  isFoundInIni: true,
  isZend: false,
  isInstalled: true,
  packageName: 'php8.5-curl',
  description: 'CURL module for PHP',
);

const _zip = PhpExtension(
  name: 'zip',
  fileName: 'zip.so',
  isEnabled: false,
  isFoundInIni: false,
  isZend: false,
  isInstalled: false,
  packageName: 'php8.5-zip',
  description: 'ZIP module for PHP',
);

Future<void> _openExtensionsTab(WidgetTester tester, PhpSettings settings) async {
  await tester.binding.setSurfaceSize(const Size(1200, 800));
  addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appsProvider.overrideWith(() => _StaticAppsNotifier()),
        phpSettingsProvider.overrideWith(() => settings),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: AppSettingsModal(app: _phpApp(), onClose: () {}),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Extensions'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('renders the package badge and the Not installed chip', (tester) async {
    await _openExtensionsTab(tester, _MockPhpSettings([_curl, _zip]));

    expect(find.text('curl'), findsOneWidget);
    expect(find.text('zip'), findsOneWidget);

    // Both cards carry their owning package name.
    expect(find.text('php8.5-curl'), findsOneWidget);
    expect(find.text('php8.5-zip'), findsOneWidget);

    // Only the not-yet-installed extension warns about a download.
    expect(find.text('Not installed'), findsOneWidget);
    final chip = find.ancestor(
      of: find.text('Not installed'),
      matching: find.byKey(const ValueKey('ext-card-zip')),
    );
    expect(chip, findsOneWidget);
  });

  testWidgets('filters by package name, not only extension name', (tester) async {
    await _openExtensionsTab(tester, _MockPhpSettings([_curl, _zip]));

    await tester.enterText(
      find.byKey(const ValueKey('extensions-search')),
      'php8.5-zip',
    );
    await tester.pumpAndSettle();

    expect(find.text('zip'), findsOneWidget);
    expect(find.text('curl'), findsNothing);
  });

  testWidgets('shows a spinner and drops the switch while a toggle is in flight', (tester) async {
    final gate = Completer<void>();
    await _openExtensionsTab(
      tester,
      _MockPhpSettings([_curl, _zip], toggleGate: gate),
    );

    await tester.tap(find.byKey(const ValueKey('ext-switch-zip')));
    await tester.pump();

    expect(find.byKey(const ValueKey('ext-spinner-zip')), findsOneWidget);
    expect(find.byKey(const ValueKey('ext-switch-zip')), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ext-spinner-zip')), findsNothing);
    expect(find.byKey(const ValueKey('ext-switch-zip')), findsOneWidget);
  });

  testWidgets('surfaces an unsupported distribution instead of spinning forever', (tester) async {
    await _openExtensionsTab(tester, _FailingPhpSettings());

    expect(find.textContaining('not supported'), findsOneWidget);
  });
}

class _FailingPhpSettings extends PhpSettings {
  @override
  Future<List<PhpExtension>> getExtensions(
    AppModel app, [
    String? iniContent,
  ]) async {
    throw UnsupportedError(
      'PHP extensions are not supported on this Linux distribution (unknown).',
    );
  }
}
