import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';
import 'package:xmu_rollcall/core/session/session_credential.dart';

typedef BytesFactory = Uint8List Function(int length);

/// App-fixed-key seal for assist packages (pseudo-security; no share passphrase).
///
/// Token shape: `xmu2.<base64url(iv || ciphertext)>`.
class AssistTokenCodec {
  AssistTokenCodec({BytesFactory? randomBytes})
      : _randomBytes = randomBytes ?? _secureBytes;

  final BytesFactory _randomBytes;

  static const prefix = 'xmu2.';

  /// Not a secret against reverse engineering — comfort obfuscation only.
  static const _material = 'xmu-rollcall-assist-seal-v2';

  static Uint8List _secureBytes(int length) {
    final r = Random.secure();
    return Uint8List.fromList(List.generate(length, (_) => r.nextInt(256)));
  }

  Uint8List get _key {
    return SHA256Digest().process(Uint8List.fromList(utf8.encode(_material)));
  }

  String seal(AssistPackagePlain plain) {
    final iv = _randomBytes(16);
    final plaintext =
        Uint8List.fromList(utf8.encode(jsonEncode(plain.toJson())));
    final ciphertext =
        _aesCbc(encrypt: true, key: _key, iv: iv, data: plaintext);
    final packed = Uint8List(iv.length + ciphertext.length)
      ..setAll(0, iv)
      ..setAll(iv.length, ciphertext);
    return '$prefix${base64Url.encode(packed).replaceAll('=', '')}';
  }

  AssistPackagePlain open(String token) {
    final trimmed = token.trim();
    if (!trimmed.startsWith(prefix)) {
      throw SessionCredentialException('不支持的凭证格式（需要 $prefix 开头）');
    }
    final b64 = trimmed.substring(prefix.length);
    late final Uint8List packed;
    try {
      packed = Uint8List.fromList(base64Url.decode(_padBase64Url(b64)));
    } catch (_) {
      throw SessionCredentialException('凭证串损坏或格式无效');
    }
    if (packed.length < 17) {
      throw SessionCredentialException('凭证串过短');
    }
    final iv = Uint8List.sublistView(packed, 0, 16);
    final ct = Uint8List.sublistView(packed, 16);
    late final Uint8List decrypted;
    try {
      decrypted = _aesCbc(encrypt: false, key: _key, iv: iv, data: ct);
    } catch (_) {
      throw SessionCredentialException('凭证串无法解密');
    }
    try {
      final map = Map<String, dynamic>.from(
        jsonDecode(utf8.decode(decrypted)) as Map,
      );
      return AssistPackagePlain.fromJson(map);
    } catch (_) {
      throw SessionCredentialException('凭证内容无效');
    }
  }

  static String _padBase64Url(String s) {
    final mod = s.length % 4;
    if (mod == 0) return s;
    return s.padRight(s.length + (4 - mod), '=');
  }

  Uint8List _aesCbc({
    required bool encrypt,
    required Uint8List key,
    required Uint8List iv,
    required Uint8List data,
  }) {
    final cipher = CBCBlockCipher(AESEngine())
      ..init(encrypt, ParametersWithIV(KeyParameter(key), iv));
    final input = encrypt ? _pkcs7Pad(data) : data;
    if (input.length % 16 != 0) {
      throw SessionCredentialException('凭证串无法解密');
    }
    final out = Uint8List(input.length);
    var offset = 0;
    while (offset < input.length) {
      offset += cipher.processBlock(input, offset, out, offset);
    }
    return encrypt ? out : _pkcs7Unpad(out);
  }

  Uint8List _pkcs7Pad(Uint8List data) {
    final pad = 16 - (data.length % 16);
    return Uint8List.fromList([...data, ...List.filled(pad, pad)]);
  }

  Uint8List _pkcs7Unpad(Uint8List data) {
    if (data.isEmpty) {
      throw SessionCredentialException('凭证串无法解密');
    }
    final pad = data.last;
    if (pad < 1 || pad > 16 || pad > data.length) {
      throw SessionCredentialException('凭证串无法解密');
    }
    for (var i = data.length - pad; i < data.length; i++) {
      if (data[i] != pad) {
        throw SessionCredentialException('凭证串无法解密');
      }
    }
    return Uint8List.sublistView(data, 0, data.length - pad);
  }
}
