import 'package:cookie_jar/cookie_jar.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';

class AcademicIdentity {
  const AcademicIdentity({
    this.username,
    this.password,
    this.sso,
    required this.isCurrent,
  });
  final String? username, password;
  final CookieJar? sso;
  final Future<bool> Function() isCurrent;
}

Future<AcademicIdentity?> resolveOwnerAcademicIdentity(
  SecureStore store,
  int uid, {
  CookieJar? sso,
  Future<bool> Function()? isCurrent,
}) async {
  if (await store.read(SecureStore.keyUserId) != '$uid') return null;
  return AcademicIdentity(
    username: await store.read(SecureStore.keyLastUsername),
    password: await store.read(SecureStore.keyOwnerPassword),
    sso: sso,
    isCurrent: () async =>
        await store.read(SecureStore.keyUserId) == '$uid' &&
        (isCurrent == null || await isCurrent()),
  );
}
