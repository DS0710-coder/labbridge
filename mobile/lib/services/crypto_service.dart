import 'dart:convert';
import 'package:cryptography/cryptography.dart';

class CryptoService {
  static final CryptoService _instance = CryptoService._internal();
  factory CryptoService() => _instance;
  CryptoService._internal();

  final _aesGcm = AesGcm.with256bits();
  final _hkdf = Hkdf(
    hmac: Hmac.sha256(),
    outputLength: 32, // 256 bits for AES-256
  );

  static final _salt = utf8.encode('LabBridge-Transfer-Salt-v1');
  static final _info = utf8.encode('LabBridge-AES-Key');

  Future<SecretKey> deriveKeyFromPairingToken(String pairingToken) async {
    final tokenBytes = utf8.encode(pairingToken);

    final secretKey = await _hkdf.deriveKey(
      secretKey: SecretKey(tokenBytes),
      nonce: _salt,
      info: _info,
    );

    return secretKey;
  }

  Future<List<int>> decryptChunk(SecretKey key, String base64EncryptedData) async {
    final combined = base64Decode(base64EncryptedData);
    if (combined.length < 28) {
      // 12 (IV) + 16 (Auth Tag) = 28 minimum bytes for empty chunk
      throw Exception('Invalid encrypted chunk payload (too short)');
    }

    final iv = combined.sublist(0, 12);
    final ciphertextAndMac = combined.sublist(12);
    final cipherBytes = ciphertextAndMac.sublist(0, ciphertextAndMac.length - 16);
    final macBytes = ciphertextAndMac.sublist(ciphertextAndMac.length - 16);

    final secretBox = SecretBox(
      cipherBytes,
      nonce: iv,
      mac: Mac(macBytes),
    );

    final decrypted = await _aesGcm.decrypt(secretBox, secretKey: key);
    return decrypted;
  }
}
