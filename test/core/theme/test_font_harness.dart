import 'dart:io';

import 'package:dev_stack/core/theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

/// Builds the real theme with local test glyphs, without fetching Google fonts.
///
/// Call from setUpAll, not main or a widget test's fake-async zone: asset IO and
/// FontLoader must finish before widgets render or the test zone goes away.
Future<ThemeData> loadThemeWithTestFonts() async {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  // flutter_tester lives at bin/cache/artifacts/engine/<platform>/ inside the
  // SDK, so this works without a machine-specific path or FLUTTER_ROOT env var.
  final sdkRoot = File(
    Platform.resolvedExecutable,
  ).uri.resolve('../../../../../');
  // Keep Flutter's deterministic square test glyphs, not real Inter metrics.
  final bytes = await File.fromUri(
    sdkRoot.resolve('packages/flutter_tools/static/Ahem.ttf'),
  ).readAsBytes();
  final fontData = ByteData.sublistView(bytes);

  const fontAssets = <String>[
    'test-fonts/Inter-Regular.ttf',
    'test-fonts/Inter-Bold.ttf',
  ];
  const codec = StandardMessageCodec();
  final manifest = <Object?, Object?>{
    ...codec.decodeMessage(await rootBundle.load('AssetManifest.bin'))
        as Map<Object?, Object?>,
    for (final asset in fontAssets)
      asset: <Object?>[
        <String, Object?>{'asset': asset},
      ],
  };
  final messenger = binding.defaultBinaryMessenger;
  final wasAllowed = GoogleFonts.config.allowRuntimeFetching;
  GoogleFonts.config.allowRuntimeFetching = false;
  rootBundle.evict('AssetManifest.bin');
  messenger.setMockMessageHandler('flutter/assets', (message) {
    final asset = const StringCodec().decodeMessage(message);
    if (asset == 'AssetManifest.bin') {
      return Future<ByteData?>.value(codec.encodeMessage(manifest));
    }
    if (fontAssets.contains(asset)) {
      return Future<ByteData?>.value(fontData);
    }
    return messenger.delegate.send('flutter/assets', message);
  });
  try {
    final theme = AppTheme.darkTheme;
    await GoogleFonts.pendingFonts();
    return theme;
  } finally {
    messenger.setMockMessageHandler('flutter/assets', null);
    rootBundle.evict('AssetManifest.bin');
    GoogleFonts.config.allowRuntimeFetching = wasAllowed;
  }
}
