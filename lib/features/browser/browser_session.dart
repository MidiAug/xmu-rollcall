import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/providers.dart';
import 'package:xmu_rollcall/core/session/session_key.dart';
import 'package:xmu_rollcall/features/assist/assist_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account.dart';

typedef BrowserIdentity = ({int? ownerId, int? userId, int? assistId});

final browserIdentityProvider = Provider<BrowserIdentity>((ref) {
  final auth = ref.watch(authControllerProvider);
  if (!auth.isSignedIn) return (ownerId: null, userId: null, assistId: null);
  final assist = ref.watch(selectedRollcallAccountProvider);
  final validAssist = ref
      .watch(assistControllerProvider)
      .identities
      .any((a) => a.userId == assist);
  return (
    ownerId: auth.profile!.id,
    userId: validAssist ? assist : auth.profile!.id,
    assistId: validAssist ? assist : null,
  );
});

String browserProfileName(BrowserIdentity identity) => identity.userId == null
    ? 'anonymous'
    : 'owner_${identity.ownerId}_user_${identity.userId}';

final idsBrowserCookiesProvider = FutureProvider.autoDispose<List<Cookie>>((
  ref,
) async {
  final identity = ref.watch(browserIdentityProvider);
  if (identity.userId == null) return const [];
  final registry = ref.read(sessionClientRegistryProvider);
  final client = registry.forKey(
    identity.assistId == null
        ? SessionKey.owner
        : SessionKey.assist(identity.assistId!),
  );
  await client.init();
  final cookies = await client.cookieJar!.loadForRequest(
    Uri.parse('https://ids.xmu.edu.cn/authserver/'),
  );
  return reusableIdsCookies(cookies);
});

/// Service sessions (lnt/portal/library) are not CAS tickets. Only IDS' own
/// SSO cookies may be seeded, at their original host/path and lifetime.
List<Cookie> reusableIdsCookies(Iterable<Cookie> cookies, {DateTime? now}) {
  final time = now ?? DateTime.now();
  return cookies
      .where((c) {
        final domain = c.domain?.toLowerCase().replaceFirst(RegExp(r'^\.'), '');
        return const {'CASTGC', 'happyVoyage'}.contains(c.name) &&
            (domain == null || domain.isEmpty || domain == 'ids.xmu.edu.cn') &&
            (c.expires == null || c.expires!.isAfter(time)) &&
            (c.maxAge == null || c.maxAge! > 0) &&
            c.value.isNotEmpty;
      })
      .toList(growable: false);
}
