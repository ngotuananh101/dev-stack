import 'package:flutter_test/flutter_test.dart';
import 'package:dev_stack/core/services/background_process.dart';

void main() {
  group('BackgroundProcess command formatting', () {
    test('builds Linux elevated command arguments correctly', () {
      final cmd = BackgroundProcess.buildLinuxElevatedArgs('cp', ['/tmp/a', '/etc/hosts']);
      expect(cmd.executable, equals('pkexec'));
      expect(cmd.arguments, equals(['cp', '/tmp/a', '/etc/hosts']));
    });
  });
}
