import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dev_stack/features/apps/data/app_installer_service.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('checksum_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('AppInstallerService - Binary Checksum Verification (VULN-12)', () {
    test('calculateFileChecksum computes correct SHA256 for known content', () async {
      final file = File('${tempDir.path}/hello.txt');
      await file.writeAsString('Hello Ponta Dev Stack!');

      // SHA256 of "Hello Ponta Dev Stack!" is a5d11bf855f9d41bd4f34678de61d7ec7961865ba98198a09689eb52a29ede12
      final computed = await AppInstallerService.calculateFileChecksum(file);
      expect(computed.toLowerCase(), 'a5d11bf855f9d41bd4f34678de61d7ec7961865ba98198a09689eb52a29ede12');
    });

    test('verifyFileChecksum returns true when hash matches (case-insensitive)', () async {
      final file = File('${tempDir.path}/hello.txt');
      await file.writeAsString('Hello Ponta Dev Stack!');

      final result = await AppInstallerService.verifyFileChecksum(
        file,
        'A5D11BF855F9D41BD4F34678DE61D7EC7961865BA98198A09689EB52A29EDE12',
      );
      expect(result, isTrue);
    });

    test('verifyFileChecksum throws ChecksumMismatchException when hash differs', () async {
      final file = File('${tempDir.path}/tampered.bin');
      await file.writeAsString('Tampered malicious payload');

      expect(
        () => AppInstallerService.verifyFileChecksum(
          file,
          'a5d11bf855f9d41bd4f34678de61d7ec7961865ba98198a09689eb52a29ede12',
        ),
        throwsA(isA<ChecksumMismatchException>().having(
          (e) => e.message,
          'message',
          contains('SHA256 checksum mismatch'),
        )),
      );
    });
  });
}
