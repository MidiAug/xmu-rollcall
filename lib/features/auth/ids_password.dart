import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// AES-CBC + PKCS7, matching `xmulogin._encrypt_password`.
const idsAesChars = 'ABCDEFGHJKMNPQRSTWXYZabcdefhijkmnprstwxyz2345678';

final _saltRe = RegExp(r'id="pwdEncryptSalt"\s+value="([^"]+)"');
final _executionRe = RegExp(r'name="execution"\s+value="([^"]+)"');

({String salt, String execution})? parseIdsLoginForm(String html) {
  final salt = _saltRe.firstMatch(html)?.group(1);
  final execution = _executionRe.firstMatch(html)?.group(1);
  if (salt == null || salt.isEmpty || execution == null || execution.isEmpty) {
    return null;
  }
  return (salt: salt, execution: execution);
}

/// IDS 登录页 HTML 里几乎总有 `id="captcha"` 等占位字段；
/// 真正要不要填验证码看 `var needCaptcha = "..."`（空字符串 = 不需要）。
/// 对齐 xmulogin：不需要时照常 POST，`captcha` 传空串。
bool idsFormLooksLikeCaptcha(String html) {
  final need = RegExp(
    r'var\s+needCaptcha\s*=\s*"([^"]*)"',
    caseSensitive: false,
  ).firstMatch(html);
  if (need != null) {
    final v = need.group(1)!.trim().toLowerCase();
    return v.isNotEmpty && v != 'false' && v != '0' && v != 'null';
  }
  // 无 needCaptcha 变量时，仅当出现可见验证码图才视为需要。
  final lower = html.toLowerCase();
  return lower.contains('id="captchaimg"') &&
      !lower.contains('var needcaptcha');
}

String randomIdsChars(int n, [Random? random]) {
  final rand = random ?? Random.secure();
  final buf = StringBuffer();
  for (var i = 0; i < n; i++) {
    buf.write(idsAesChars[rand.nextInt(idsAesChars.length)]);
  }
  return buf.toString();
}

String encryptIdsPassword(String password, String salt, [Random? random]) {
  final plaintext = '${randomIdsChars(64, random)}$password';
  final key = Uint8List.fromList(utf8.encode(salt));
  final iv = Uint8List.fromList(utf8.encode(randomIdsChars(16, random)));
  final input = _pkcs7(Uint8List.fromList(utf8.encode(plaintext)));

  final cipher = CBCBlockCipher(AESEngine())
    ..init(true, ParametersWithIV(KeyParameter(key), iv));

  final out = Uint8List(input.length);
  var offset = 0;
  while (offset < input.length) {
    offset += cipher.processBlock(input, offset, out, offset);
  }
  return base64Encode(out);
}

Uint8List _pkcs7(Uint8List data) {
  final pad = 16 - (data.length % 16);
  return Uint8List.fromList([...data, ...List.filled(pad, pad)]);
}
