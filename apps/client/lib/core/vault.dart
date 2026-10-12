import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'study.dart';

class StudyVault {
  static const storageKey = 'blue.encrypted-vault.v1';
  static const maxBytes = 24 * 1024 * 1024;
  final _cipher = AesGcm.with256bits();
  final _kdf = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 210000,
    bits: 256,
  );
  Future<bool> exists() async =>
      (await SharedPreferences.getInstance()).containsKey(storageKey);
  Future<SecretKey> _key(String password, List<int> salt) =>
      _kdf.deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);

  Future<String> encrypt(List<Study> studies, String password) async {
    if (password.length < 12) {
      throw const FormatException(
        'Use a passphrase of at least 12 characters.',
      );
    }
    final clear = utf8.encode(
      jsonEncode(studies.map((s) => s.toJson()).toList()),
    );
    if (clear.length > maxBytes) {
      throw const FormatException(
        'Vault limit is 24 MiB. Export or remove studies before saving.',
      );
    }
    final salt = SecretKeyData.random(length: 16).bytes;
    final box = await _cipher.encrypt(
      clear,
      secretKey: await _key(password, salt),
      aad: utf8.encode(storageKey),
    );
    return jsonEncode({
      'v': 1,
      'salt': base64Encode(salt),
      'nonce': base64Encode(box.nonce),
      'mac': base64Encode(box.mac.bytes),
      'data': base64Encode(box.cipherText),
    });
  }

  Future<List<Study>> decrypt(String payload, String password) async {
    if (payload.length > maxBytes * 2) {
      throw const FormatException('Vault exceeds the supported size.');
    }
    final data = jsonDecode(payload) as Map<String, dynamic>;
    if (data['v'] != 1) {
      throw const FormatException('Unsupported vault version.');
    }
    final box = SecretBox(
      base64Decode(data['data'] as String),
      nonce: base64Decode(data['nonce'] as String),
      mac: Mac(base64Decode(data['mac'] as String)),
    );
    final clear = await _cipher.decrypt(
      box,
      secretKey: await _key(password, base64Decode(data['salt'] as String)),
      aad: utf8.encode(storageKey),
    );
    final entries = jsonDecode(utf8.decode(clear));
    if (entries is! List || entries.length > 100) {
      throw const FormatException('Invalid study list in vault.');
    }
    final studies = entries
        .map((s) => Study.fromJson(s as Map<String, dynamic>))
        .toList();
    if (studies.map((s) => s.id).toSet().length != studies.length ||
        studies.fold<int>(0, (n, s) => n + s.byteSize) > 16 * 1024 * 1024) {
      throw const FormatException('Invalid or oversized vault.');
    }
    return studies;
  }

  Future<void> save(List<Study> studies, String password) async {
    final encrypted = await encrypt(studies, password);
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(storageKey, encrypted)) {
      throw StateError('Storage write failed');
    }
  }

  Future<List<Study>> load(String password) async {
    final payload = (await SharedPreferences.getInstance()).getString(
      storageKey,
    );
    if (payload == null) return [];
    return decrypt(payload, password);
  }

  Future<Uint8List> backup(List<Study> studies, String password) async =>
      Uint8List.fromList(utf8.encode(await encrypt(studies, password)));
}
