import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Vault for encrypting sensitive values (passwords, tokens) stored locally.
///
/// Uses an authenticated encryption scheme:
/// - Key derivation: SHA-256 over master key + IV
/// - Encryption: Stream cipher XOR using SHA-256 keystream
/// - Integrity: HMAC-SHA256 authentication tag
/// Format: `ENC:<base64_iv>:<base64_ciphertext>:<base64_hmac>`
///
/// Transparent backward compatibility: if a string does not start with `ENC:`,
/// it is treated as legacy plaintext and returned verbatim.
class LocalSecretVault {
  static const String prefix = 'ENC:';
  static LocalSecretVault? _defaultInstance;

  final Uint8List _keyBytes;

  LocalSecretVault._(this._keyBytes);

  factory LocalSecretVault.withKey(String key) {
    final keyHash = sha256.convert(utf8.encode(key)).bytes;
    return LocalSecretVault._(Uint8List.fromList(keyHash));
  }

  static Future<LocalSecretVault> getInstance({File? keyFile}) async {
    if (keyFile != null) {
      return await fromFile(keyFile);
    }
    if (_defaultInstance != null) {
      return _defaultInstance!;
    }
    final supportDir = await getApplicationSupportDirectory();
    final defaultKeyFile = File(p.join(supportDir.path, '.devstack_vault.key'));
    _defaultInstance = await fromFile(defaultKeyFile);
    return _defaultInstance!;
  }

  static Future<LocalSecretVault> fromFile(File file) async {
    if (await file.exists()) {
      final content = (await file.readAsString()).trim();
      if (content.isNotEmpty) {
        return LocalSecretVault.withKey(content);
      }
    }

    // Generate secure 256-bit random key
    final random = Random.secure();
    final randomBytes = List<int>.generate(32, (_) => random.nextInt(256));
    final keyString = base64Url.encode(randomBytes);

    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }
    await file.writeAsString(keyString);

    // Tighten file permissions on POSIX
    if (!Platform.isWindows) {
      try {
        await Process.run('chmod', ['600', file.path]);
      } catch (_) {}
    }

    return LocalSecretVault.withKey(keyString);
  }

  String encrypt(String plaintext) {
    if (plaintext.isEmpty) return '';

    // Generate 16-byte random IV
    final random = Random.secure();
    final iv = List<int>.generate(16, (_) => random.nextInt(256));

    final plainBytes = utf8.encode(plaintext);
    final cipherBytes = _cryptStream(plainBytes, iv);

    // Compute HMAC-SHA256 over IV + ciphertext
    final hmacKey = Hmac(sha256, _keyBytes);
    final authTag = hmacKey.convert([...iv, ...cipherBytes]).bytes;

    final ivB64 = base64Url.encode(iv);
    final cipherB64 = base64Url.encode(cipherBytes);
    final tagB64 = base64Url.encode(authTag);

    return '$prefix$ivB64:$cipherB64:$tagB64';
  }

  String decrypt(String ciphertext) {
    if (ciphertext.isEmpty) return '';
    if (!ciphertext.startsWith(prefix)) {
      // Legacy plaintext password (backward compatible)
      return ciphertext;
    }

    final payload = ciphertext.substring(prefix.length);
    final parts = payload.split(':');
    if (parts.length != 3) {
      throw const FormatException('Invalid encrypted format for LocalSecretVault');
    }

    final iv = base64Url.decode(parts[0]);
    final cipherBytes = base64Url.decode(parts[1]);
    final expectedTag = base64Url.decode(parts[2]);

    // Verify HMAC
    final hmacKey = Hmac(sha256, _keyBytes);
    final actualTag = hmacKey.convert([...iv, ...cipherBytes]).bytes;

    if (!_constantTimeEquals(actualTag, expectedTag)) {
      throw const FormatException('Authentication failed: HMAC mismatch in LocalSecretVault');
    }

    final plainBytes = _cryptStream(cipherBytes, iv);
    return utf8.decode(plainBytes);
  }

  List<int> _cryptStream(List<int> input, List<int> iv) {
    final output = Uint8List(input.length);
    var blockIndex = 0;
    var offset = 0;

    while (offset < input.length) {
      // Keystream block = sha256(key || iv || blockIndex)
      final blockData = [
        ..._keyBytes,
        ...iv,
        (blockIndex >> 24) & 0xFF,
        (blockIndex >> 16) & 0xFF,
        (blockIndex >> 8) & 0xFF,
        blockIndex & 0xFF,
      ];
      final keyStreamBlock = sha256.convert(blockData).bytes;

      for (var i = 0; i < keyStreamBlock.length && offset < input.length; i++, offset++) {
        output[offset] = input[offset] ^ keyStreamBlock[i];
      }
      blockIndex++;
    }

    return output;
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }
}
