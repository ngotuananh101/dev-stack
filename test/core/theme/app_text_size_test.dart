import 'dart:io';

import 'package:dev_stack/core/theme/app_text_size.dart';
import 'package:flutter_test/flutter_test.dart';

/// The app is a dense desktop tool: every label, cell, form field and button
/// reads at one size, and hierarchy comes from weight and colour instead of
/// another step on the type scale. These tests pin the scale and the rule that
/// keeps new code on it.
void main() {
  test('the body size is 12 and the scale keeps its fixed steps', () {
    expect(AppTextSize.xxxs, 8);
    expect(AppTextSize.xxs, 10);
    expect(
      AppTextSize.xs,
      12,
      reason: 'the app-wide body size the UI is designed against',
    );
    expect(AppTextSize.sm, 14);
    expect(AppTextSize.base, 16);
    expect(AppTextSize.lg, 18);
    expect(AppTextSize.xxl, greaterThan(AppTextSize.base));
  });

  test('no Dart file under lib/ hardcodes a font size', () {
    // A literal number here is how the tables drifted apart: each new cell
    // picked its own step and the row ended up at three sizes at once. Tokens
    // keep every call site on the same scale, so the next change is one edit.
    final offenders = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (RegExp(r'fontSize:\s*[0-9]').hasMatch(line)) {
          offenders.add('${file.path}:${i + 1}: ${line.trim()}');
        }
      }
    }

    expect(offenders, isEmpty, reason: 'use an AppTextSize token instead');
  });
}
