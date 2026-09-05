import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dev_stack/core/security/local_secret_vault.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('vault_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('LocalSecretVault - Sensitive Credential Encryption (VULN-11)', () {
    test('encrypt returns empty string when plaintext is empty', () {
      final vault = LocalSecretVault.withKey('test-secret-key-32-chars-long!!');
      expect(vault.encrypt(''), '');
      expect(vault.decrypt(''), '');
    });

    test('encrypt produces formatted ciphertext with ENC: prefix', () {
      final vault = LocalSecretVault.withKey('test-secret-key-32-chars-long!!');
      final ciphertext = vault.encrypt('my_super_secret_db_pass');

      expect(ciphertext, startsWith('ENC:'));
      expect(ciphertext, isNot(contains('my_super_secret_db_pass')));
    });

    test('decrypt correctly restores original plaintext from ciphertext', () {
      final vault = LocalSecretVault.withKey('test-secret-key-32-chars-long!!');
      const secret = 'p@ssw0rd_1234_!@#\$%^&*()';
      final ciphertext = vault.encrypt(secret);
      final decrypted = vault.decrypt(ciphertext);

      expect(decrypted, secret);
    });

    test('decrypt handles legacy plaintext gracefully without crashing (backward compatible)', () {
      final vault = LocalSecretVault.withKey('test-secret-key-32-chars-long!!');
      const legacyPlaintext = 'unencrypted_old_database_password';

      // Plaintext doesn't start with ENC: so it should return verbatim
      final decrypted = vault.decrypt(legacyPlaintext);
      expect(decrypted, legacyPlaintext);
    });

    test('encrypting the same plaintext twice produces different ciphertexts due to random IV', () {
      final vault = LocalSecretVault.withKey('test-secret-key-32-chars-long!!');
      const secret = 'identical_password';

      final c1 = vault.encrypt(secret);
      final c2 = vault.encrypt(secret);

      expect(c1, isNot(equals(c2)));
      expect(vault.decrypt(c1), secret);
      expect(vault.decrypt(c2), secret);
    });

    test('detects tampering and throws FormatException on invalid HMAC tag', () {
      final vault = LocalSecretVault.withKey('test-secret-key-32-chars-long!!');
      final ciphertext = vault.encrypt('secret_value');

      // Format: ENC:<iv>:<ciphertext>:<mac>
      final parts = ciphertext.split(':');
      expect(parts.length, 4);

      // Tamper ciphertext
      final tampered = 'ENC:${parts[1]}:badpayload:${parts[3]}';
      expect(() => vault.decrypt(tampered), throwsA(isA<FormatException>()));
    });

    test('persists and reloads master key from file correctly', () async {
      final keyFile = File('${tempDir.path}/master.key');
      final vault1 = await LocalSecretVault.fromFile(keyFile);
      final encrypted = vault1.encrypt('persistent_secret');

      // Create new vault instance using the same key file
      final vault2 = await LocalSecretVault.fromFile(keyFile);
      expect(vault2.decrypt(encrypted), 'persistent_secret');
    });
  });
}
