import 'package:flutter_test/flutter_test.dart';

/// Tests for AppsRepository are skipped because they require Isar native library
/// (isar.dll) which is not available in the test environment.
///
/// To test the repository layer, you would need to:
/// 1. Ensure isar_flutter_libs is properly configured
/// 2. Run tests with the native Isar binaries available
/// 3. Or use integration tests instead of unit tests
void main() {
  group('AppsRepository', () {
    test('requires native Isar library', () {
      // This test suite is skipped because Isar requires native DLL
      // that is not available in the standard test environment.
    }, skip: 'Requires Isar native library (isar.dll)');
  });
}
