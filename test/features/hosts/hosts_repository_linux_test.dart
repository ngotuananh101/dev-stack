import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dev_stack/features/hosts/data/hosts_repository.dart';

void main() {
  group('HostsRepository OS support', () {
    test('hostsPath points to correct OS path', () {
      if (Platform.isLinux) {
        expect(HostsRepository.hostsPath, equals('/etc/hosts'));
      } else if (Platform.isWindows) {
        expect(
          HostsRepository.hostsPath,
          equals(r'C:\Windows\System32\drivers\etc\hosts'),
        );
      }
    });

    test('hostsPath returns Linux hosts path when resolved for Linux', () {
      expect(HostsRepository.resolveHostsPath(isLinux: true), equals('/etc/hosts'));
      expect(
        HostsRepository.resolveHostsPath(isLinux: false),
        equals(r'C:\Windows\System32\drivers\etc\hosts'),
      );
    });
  });
}

