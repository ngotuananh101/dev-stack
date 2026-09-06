import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Bun and Deno brand icon assets', () {
    test('assets/images/bun.png exists and is a valid non-empty PNG', () async {
      final file = File('assets/images/bun.png');
      expect(await file.exists(), isTrue, reason: 'bun.png must exist in assets/images/');
      final bytes = await file.readAsBytes();
      expect(bytes.length, greaterThan(100), reason: 'bun.png must be non-empty');
      // PNG header: 0x89 0x50 0x4E 0x47 0x0D 0x0A 0x1A 0x0A
      expect(bytes.sublist(0, 8), equals([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));
    });

    test('assets/images/deno.png exists and is a valid non-empty PNG', () async {
      final file = File('assets/images/deno.png');
      expect(await file.exists(), isTrue, reason: 'deno.png must exist in assets/images/');
      final bytes = await file.readAsBytes();
      expect(bytes.length, greaterThan(100), reason: 'deno.png must be non-empty');
      // PNG header: 0x89 0x50 0x4E 0x47 0x0D 0x0A 0x1A 0x0A
      expect(bytes.sublist(0, 8), equals([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));
    });
  });
}
