import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:pointycastle/export.dart';
import 'package:xmu_rollcall/core/session/session_credential.dart';

typedef BytesFactory = Uint8List Function(int length);

/// Passphrase seal/open for [SessionCredentialPlain] (PBKDF2-SHA256 + AES-CBC).
class SessionCredentialCrypto {
  SessionCredentialCrypto({
    BytesFactory? randomBytes,
    this.iterations = 100000,
  }) : _randomBytes = randomBytes ?? _secureBytes;

  final BytesFactory _randomBytes;
  final int iterations;

  static const formatId = 'xmu-rollcall-session-v1';

  static Uint8List _secureBytes(int length) {
    final r = Random.secure();
    return Uint8List.fromList(List.generate(length, (_) => r.nextInt(256)));
  }

  /// Heavy KDF — prefer [sealAsync] on the UI isolate.
  String seal(SessionCredentialPlain plain, String passphrase) {
    if (passphrase.trim().isEmpty) {
      throw SessionCredentialException('口令不能为空');
    }
    final salt = _randomBytes(16);
    final iv = _randomBytes(16);
    final key = _deriveKey(passphrase, salt, iterations);
    final plaintext =
        Uint8List.fromList(utf8.encode(jsonEncode(plain.toJson())));
    final ciphertext =
        _aesCbc(encrypt: true, key: key, iv: iv, data: plaintext);

    final envelope = {
      'format': formatId,
      'kdf': 'pbkdf2-sha256',
      'iter': iterations,
      'salt_b64': base64Encode(salt),
      'iv_b64': base64Encode(iv),
      'ciphertext_b64': base64Encode(ciphertext),
    };
    return const JsonEncoder.withIndent('  ').convert(envelope);
  }

  /// Runs [seal] on a background isolate (PBKDF2 must not block the UI).
  Future<String> sealAsync(
    SessionCredentialPlain plain,
    String passphrase,
  ) {
    return compute(
      _sealIsolate,
      _SealArgs(
        plainJson: plain.toJson(),
        passphrase: passphrase,
        iterations: iterations,
      ),
    );
  }

  /// Heavy KDF — prefer [openAsync] on the UI isolate.
  SessionCredentialPlain open(String sealed, String passphrase) {
    if (passphrase.trim().isEmpty) {
      throw SessionCredentialException('口令不能为空');
    }
    late final Map<String, dynamic> envelope;
    try {
      envelope = Map<String, dynamic>.from(jsonDecode(sealed) as Map);
    } catch (_) {
      throw SessionCredentialException('凭证包格式无效');
    }
    if (envelope['format'] != formatId) {
      throw SessionCredentialException('不支持的凭证包版本');
    }
    final iter = (envelope['iter'] as num?)?.toInt() ?? iterations;
    final salt = base64Decode(envelope['salt_b64'] as String? ?? '');
    final iv = base64Decode(envelope['iv_b64'] as String? ?? '');
    final ct = base64Decode(envelope['ciphertext_b64'] as String? ?? '');
    if (salt.isEmpty || iv.length != 16 || ct.isEmpty) {
      throw SessionCredentialException('凭证包字段不完整');
    }
    final key = _deriveKey(passphrase, Uint8List.fromList(salt), iter);
    late final Uint8List decrypted;
    try {
      decrypted = _aesCbc(
        encrypt: false,
        key: key,
        iv: Uint8List.fromList(iv),
        data: Uint8List.fromList(ct),
      );
    } catch (_) {
      throw SessionCredentialException('口令错误或凭证已损坏');
    }
    try {
      final map = Map<String, dynamic>.from(
        jsonDecode(utf8.decode(decrypted)) as Map,
      );
      return SessionCredentialPlain.fromJson(map);
    } catch (_) {
      throw SessionCredentialException('口令错误或凭证已损坏');
    }
  }

  Future<SessionCredentialPlain> openAsync(
    String sealed,
    String passphrase,
  ) async {
    final map = await compute(
      _openIsolate,
      _OpenArgs(
        sealed: sealed,
        passphrase: passphrase,
        iterations: iterations,
      ),
    );
    return SessionCredentialPlain.fromJson(map);
  }

  Uint8List _deriveKey(String passphrase, Uint8List salt, int iter) {
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, iter, 32));
    return derivator.process(Uint8List.fromList(utf8.encode(passphrase)));
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
      throw SessionCredentialException('口令错误或凭证已损坏');
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
      throw SessionCredentialException('口令错误或凭证已损坏');
    }
    final pad = data.last;
    if (pad < 1 || pad > 16 || pad > data.length) {
      throw SessionCredentialException('口令错误或凭证已损坏');
    }
    for (var i = data.length - pad; i < data.length; i++) {
      if (data[i] != pad) {
        throw SessionCredentialException('口令错误或凭证已损坏');
      }
    }
    return Uint8List.sublistView(data, 0, data.length - pad);
  }
}

class _SealArgs {
  const _SealArgs({
    required this.plainJson,
    required this.passphrase,
    required this.iterations,
  });

  final Map<String, dynamic> plainJson;
  final String passphrase;
  final int iterations;
}

class _OpenArgs {
  const _OpenArgs({
    required this.sealed,
    required this.passphrase,
    required this.iterations,
  });

  final String sealed;
  final String passphrase;
  final int iterations;
}

String _sealIsolate(_SealArgs args) {
  final crypto = SessionCredentialCrypto(iterations: args.iterations);
  return crypto.seal(
    SessionCredentialPlain.fromJson(args.plainJson),
    args.passphrase,
  );
}

Map<String, dynamic> _openIsolate(_OpenArgs args) {
  final crypto = SessionCredentialCrypto(iterations: args.iterations);
  return crypto.open(args.sealed, args.passphrase).toJson();
}
