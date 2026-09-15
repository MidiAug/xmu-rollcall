import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/features/auth/ids_password.dart';

void main() {
  test('parseIdsLoginForm extracts salt and execution', () {
    const html = '''
<form>
<input id="pwdEncryptSalt" value="AbCdEfGhIjKlMnOp" />
<input name="execution" value="e1s1" />
</form>
''';
    final f = parseIdsLoginForm(html);
    expect(f?.salt, 'AbCdEfGhIjKlMnOp');
    expect(f?.execution, 'e1s1');
  });

  test('encryptIdsPassword is deterministic with fixed Random', () {
    final r1 = Random(1);
    final r2 = Random(1);
    final a = encryptIdsPassword('secret', '1234567890abcdef', r1);
    final b = encryptIdsPassword('secret', '1234567890abcdef', r2);
    expect(a, b);
    expect(a, isNotEmpty);
  });

  test('idsFormLooksLikeCaptcha ignores empty needCaptcha placeholders', () {
    const html = '''
<input id="captcha" name="captcha" />
<img id="captchaImg" />
<script>var needCaptcha = "";</script>
''';
    expect(idsFormLooksLikeCaptcha(html), isFalse);
  });

  test('idsFormLooksLikeCaptcha detects required captcha', () {
    const html = '''
<input id="captcha" name="captcha" />
<script>var needCaptcha = "true";</script>
''';
    expect(idsFormLooksLikeCaptcha(html), isTrue);
  });
}
