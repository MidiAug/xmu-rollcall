import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/providers.dart';
import 'package:xmu_rollcall/core/network/rate_limiter.dart';
import 'package:xmu_rollcall/core/session/assist_identity_store.dart';
import 'package:xmu_rollcall/core/session/assist_service.dart';
import 'package:xmu_rollcall/core/session/session_key.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';
import 'academic_session.dart';
import 'academic_identity.dart';

final academicRateLimiterProvider = Provider<RateLimiter>(
  (ref) => RateLimiter(),
);
final academicSessionFactoryProvider = Provider<AcademicSession Function()>((
  ref,
) {
  final store = ref.watch(secureStoreProvider);
  final limiter = ref.watch(academicRateLimiterProvider);
  return () => AcademicSession(store: store, limiter: limiter);
});

final academicIdentityResolverProvider =
    Provider<Future<AcademicIdentity?> Function(int)>((ref) {
      return (uid) async {
        final store = ref.read(secureStoreProvider);
        final owner = await store.read(SecureStore.keyUserId);
        if (owner == null) return null;
        if (owner == '$uid') {
          final client = ref.read(sessionClientRegistryProvider).owner();
          final revision = client.sessionRevision;
          return resolveOwnerAcademicIdentity(
            store,
            uid,
            sso: client.cookieJar,
            isCurrent: () async => client.sessionRevision == revision,
          );
        }
        final roster = AssistIdentityStore(store);
        final identity = (await roster.list())
            .where((i) => i.userId == uid)
            .firstOrNull;
        if (identity == null) return null;
        final raw = await store.read(AssistService.accountCredKey(uid));
        final credentials = raw == null
            ? const <String, dynamic>{}
            : jsonDecode(raw) as Map;
        final client = ref
            .read(sessionClientRegistryProvider)
            .forKey(SessionKey.assist(uid));
        await client.init();
        final revision = client.sessionRevision;
        return AcademicIdentity(
          username: credentials['username'] as String? ?? identity.studentNo,
          password: credentials['password'] as String?,
          sso: client.cookieJar,
          isCurrent: () async =>
              await store.read(SecureStore.keyUserId) == owner &&
              client.sessionRevision == revision &&
              (await roster.list()).any((i) => i.userId == uid),
        );
      };
    });
