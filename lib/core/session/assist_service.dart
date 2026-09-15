import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/network/tron_endpoints.dart';
import 'package:xmu_rollcall/core/network/tron_http_client.dart';
import 'package:xmu_rollcall/core/session/assist_identity.dart';
import 'package:xmu_rollcall/core/session/assist_identity_store.dart';
import 'package:xmu_rollcall/core/session/session_client_registry.dart';
import 'package:xmu_rollcall/core/session/session_credential.dart';
import 'package:xmu_rollcall/core/session/session_credential_crypto.dart';
import 'package:xmu_rollcall/core/session/session_key.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';

class AssistProfileSnapshot {
  const AssistProfileSnapshot({required this.id, required this.name});
  final int id;
  final String name;
}

typedef AssistProfileProber = Future<AssistProfileSnapshot> Function(
  TronHttpClient client,
);

class AssistException implements Exception {
  AssistException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Export / import assist sessions (ADR-004 P3b). Discovery stays on owner.
class AssistService {
  AssistService({
    required SecureStore store,
    required this.registry,
    required this.prefs,
    SessionCredentialCrypto? crypto,
    AssistIdentityStore? roster,
    this.probeProfile,
  })  : _crypto = crypto ?? SessionCredentialCrypto(),
        _roster = roster ?? AssistIdentityStore(store);

  final SessionClientRegistry registry;
  final SharedPreferences prefs;
  final SessionCredentialCrypto _crypto;
  final AssistIdentityStore _roster;
  final AssistProfileProber? probeProfile;

  static const prefsEnabledKey = 'assist_enabled';
  static const defaultTtl = Duration(hours: 24);

  Future<bool> isEnabled() async => prefs.getBool(prefsEnabledKey) ?? false;

  Future<void> setEnabled(bool value) async {
    await prefs.setBool(prefsEnabledKey, value);
  }

  Future<List<AssistIdentity>> listIdentities() => _roster.list();

  Future<String> exportOwnerPackage({
    required String passphrase,
    required int profileId,
    required String profileName,
    DateTime? now,
    Duration ttl = defaultTtl,
  }) async {
    final owner = registry.owner();
    await owner.init();
    final cookies = await owner.exportCookiesJson();
    if (cookies == null || cookies.isEmpty) {
      throw AssistException('当前没有可导出的主号会话，请先登录');
    }
    final at = (now ?? DateTime.now()).toUtc();
    final plain = SessionCredentialPlain(
      cookiesJson: cookies,
      profileId: profileId,
      profileName: profileName,
      exportedAt: at,
      suggestedExpiresAt: at.add(ttl),
    );
    return _crypto.sealAsync(plain, passphrase);
  }

  Future<AssistIdentity> importPackage({
    required String sealed,
    required String passphrase,
    DateTime? now,
    /// Logged-in owner profile id — importing self is rejected.
    int? ownerUserId,
  }) async {
    final plain = await _crypto.openAsync(sealed, passphrase);
    final clock = (now ?? DateTime.now()).toUtc();
    if (plain.isSuggestedExpired(clock)) {
      throw SessionCredentialException('凭证包已过建议有效期，请对方重新导出');
    }
    if (plain.profileId <= 0) {
      throw AssistException('凭证包缺少有效用户 ID');
    }
    if (ownerUserId != null &&
        ownerUserId > 0 &&
        plain.profileId == ownerUserId) {
      throw AssistException('不能导入当前登录账号自己的凭证');
    }

    final key = SessionKey.assist(plain.profileId);
    final client = registry.forKey(key);
    await client.importCookiesJson(plain.cookiesJson);

    final probed = await _probe(client);
    if (ownerUserId != null && ownerUserId > 0 && probed.id == ownerUserId) {
      await registry.disposeAssist(probed.id);
      throw AssistException('不能导入当前登录账号自己的凭证');
    }
    final identity = AssistIdentity(
      userId: probed.id,
      displayName: probed.name,
      importedAt: clock,
      suggestedExpiresAt: plain.suggestedExpiresAt,
    );
    await _roster.upsert(identity);
    return identity;
  }

  Future<void> removeIdentity(int userId) async {
    await registry.disposeAssist(userId);
    await _roster.remove(userId);
  }

  Future<AssistProfileSnapshot> _probe(TronHttpClient client) async {
    final custom = probeProfile;
    if (custom != null) return custom(client);
    final res =
        await client.getUri<Map<String, dynamic>>(TronEndpoints.profile());
    final data = res.data;
    if (data == null) throw AssistException('协助会话探活失败：无资料');
    final id = (data['id'] as num?)?.toInt() ?? 0;
    final name = (data['name'] as String?) ??
        (data['user_name'] as String?) ??
        '用户';
    if (id <= 0) throw AssistException('协助会话探活失败：无效用户');
    return AssistProfileSnapshot(id: id, name: name);
  }
}
