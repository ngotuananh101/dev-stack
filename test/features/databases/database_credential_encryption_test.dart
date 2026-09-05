import 'package:flutter_test/flutter_test.dart';
import 'package:dev_stack/core/security/local_secret_vault.dart';
import 'package:dev_stack/features/databases/data/databases_provider.dart';
import 'package:dev_stack/features/databases/domain/database_record.dart';

void main() {
  group('Database Credential Encryption Helpers (VULN-11)', () {
    final vault = LocalSecretVault.withKey('test-key-32-chars-for-testing!!');

    test('encryptRecordPassword encrypts plaintext password with ENC: prefix', () {
      final record = DatabaseRecord()
        ..name = 'test_db'
        ..username = 'test_user'
        ..password = 'plaintext_pass_123'
        ..engineAppId = 'mysql'
        ..createdAt = DateTime.now();

      DatabasesNotifier.encryptRecordPassword(record, vault: vault);

      expect(record.password, startsWith('ENC:'));
      expect(record.password, isNot(contains('plaintext_pass_123')));
    });

    test('encryptRecordPassword leaves empty password unchanged', () {
      final record = DatabaseRecord()
        ..name = 'test_db'
        ..username = 'test_user'
        ..password = ''
        ..engineAppId = 'mysql'
        ..createdAt = DateTime.now();

      DatabasesNotifier.encryptRecordPassword(record, vault: vault);
      expect(record.password, '');
    });

    test('decryptRecordPassword restores original plaintext from ENC: string', () {
      final ciphertext = vault.encrypt('my_secret_pass');
      final record = DatabaseRecord()
        ..name = 'test_db'
        ..username = 'test_user'
        ..password = ciphertext
        ..engineAppId = 'mysql'
        ..createdAt = DateTime.now();

      DatabasesNotifier.decryptRecordPassword(record, vault: vault);
      expect(record.password, 'my_secret_pass');
    });

    test('decryptRecordPassword handles legacy plaintext password gracefully', () {
      final record = DatabaseRecord()
        ..name = 'test_db'
        ..username = 'test_user'
        ..password = 'legacy_unencrypted_password'
        ..engineAppId = 'mysql'
        ..createdAt = DateTime.now();

      DatabasesNotifier.decryptRecordPassword(record, vault: vault);
      expect(record.password, 'legacy_unencrypted_password');
    });
  });
}
