import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:uuid/uuid.dart';
import 'package:xmu_rollcall/core/network/tron_http_client.dart';
import 'package:xmu_rollcall/core/network/tron_endpoints.dart';
import 'package:xmu_rollcall/core/session/assist_identity.dart';
import 'package:xmu_rollcall/core/session/assist_identity_store.dart';
import 'package:xmu_rollcall/core/session/session_client_registry.dart';
import 'package:xmu_rollcall/core/session/session_credential.dart';
import 'package:xmu_rollcall/core/session/session_credential_crypto.dart';
import 'package:xmu_rollcall/core/session/session_key.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';

class AssistProfileSnapshot {
  const AssistProfileSnapshot({required this.id, required this.name});
  final int id;
  final String name;
}

typedef AssistProfileProber = Future<AssistProfileSnapshot> Function(
  TronHttpClient client,
);

typedef AssistAccountLoginFn = Future<AssistProfileSnapshot> Function({
  required String username,
  required String password,
  required TronHttpClient targetClient,
});

/// Returns course catalog for a session (owner or assist).
typedef AssistCourseCatalogFn = Future<List<AssistSharedCourse>> Function(
  TronHttpClient client,
);

class AssistException implements Exception {
  AssistException(this.message);
  final String message;

  @override
  String toString() => message;
}

enum AssistExportKind { session, account }

/// Export / import assist sessions (ADR-004 P3b dual track).
class AssistService {
  AssistService({
    required SecureStore store,
    required this.registry,
    AssistTokenCodec? codec,
    AssistIdentityStore? roster,
    this.probeProfile,
    this.accountLogin,
    this.courseCatalog,
  })  : _store = store,
        _codec = codec ?? AssistTokenCodec(),
        _roster = roster ?? AssistIdentityStore(store);

  final SecureStore _store;
  final SessionClientRegistry registry;
  final AssistTokenCodec _codec;
  final AssistIdentityStore _roster;
  final AssistProfileProber? probeProfile;
  final AssistAccountLoginFn? accountLogin;
  final AssistCourseCatalogFn? courseCatalog;

  static String accountCredKey(int userId) => 'assist_account_cred_$userId';

  Future<List<AssistIdentity>> listIdentities() async {
    final list = await _roster.list();
    final out = <AssistIdentity>[];
    for (final e in list) {
      out.add(await ensureDeviceId(e));
    }
    return out;
  }

  /// Never reuse the owner install [DeviceIdentity] for assists (same rollcall
  /// multi-student collision). Empty → mint and persist a stable UUID.
  Future<AssistIdentity> ensureDeviceId(AssistIdentity identity) async {
    final existing = identity.deviceId?.trim() ?? '';
    if (existing.isNotEmpty) return identity;
    final next = identity.copyWith(deviceId: _newDeviceId());
    await _roster.upsert(next);
    return next;
  }

  static String _newDeviceId() => const Uuid().v4();

  static String _nonEmptyDeviceId(String? raw) {
    final t = raw?.trim() ?? '';
    if (t.isNotEmpty) return t;
    return _newDeviceId();
  }

  Future<String> exportOwnerPackage({
    required AssistExportKind kind,
    required int profileId,
    required String profileName,
    required String deviceId,
    String? username,
    String? password,
    DateTime? now,
  }) async {
    final at = (now ?? DateTime.now()).toUtc();
    if (deviceId.trim().isEmpty) {
      throw AssistException('缺少设备 ID，无法导出');
    }

    switch (kind) {
      case AssistExportKind.session:
        final owner = registry.owner();
        await owner.init();
        final cookies = await owner.exportCookiesJson();
        if (cookies == null || cookies.isEmpty) {
          throw AssistException('当前没有可导出的登录会话，请先登录');
        }
        return _codec.seal(
          AssistPackagePlain(
            kind: AssistCredentialKind.session,
            deviceId: deviceId,
            profileId: profileId,
            profileName: profileName,
            exportedAt: at,
            cookiesJson: cookies,
          ),
        );
      case AssistExportKind.account:
        final user = username?.trim() ?? '';
        final pass = password ?? '';
        if (user.isEmpty || pass.isEmpty) {
          throw AssistException('导出凭证需要学号和密码');
        }
        return _codec.seal(
          AssistPackagePlain(
            kind: AssistCredentialKind.account,
            deviceId: deviceId,
            profileId: profileId,
            profileName: profileName,
            exportedAt: at,
            username: user,
            password: pass,
          ),
        );
    }
  }

  /// Import a sealed `xmu2.…` token (session or account).
  Future<AssistIdentity> importToken(
    String token, {
    DateTime? now,
    int? ownerUserId,
  }) async {
    final plain = _codec.open(token);
    final clock = (now ?? DateTime.now()).toUtc();
    return _ingestPackage(plain, clock: clock, ownerUserId: ownerUserId);
  }

  /// Import plain IDS username/password (no sealed token).
  Future<AssistIdentity> importPlainAccount({
    required String username,
    required String password,
    DateTime? now,
    int? ownerUserId,
    String? deviceId,
  }) async {
    final clock = (now ?? DateTime.now()).toUtc();
    final id = _nonEmptyDeviceId(deviceId);
    final plain = AssistPackagePlain(
      kind: AssistCredentialKind.account,
      deviceId: id,
      profileId: 0,
      profileName: username.trim(),
      exportedAt: clock,
      username: username.trim(),
      password: password,
    );
    return _ingestPackage(plain, clock: clock, ownerUserId: ownerUserId);
  }

  Future<AssistIdentity> _ingestPackage(
    AssistPackagePlain plain, {
    required DateTime clock,
    int? ownerUserId,
  }) async {
    if (plain.kind == AssistCredentialKind.session) {
      if (plain.profileId <= 0) {
        throw AssistException('协助码缺少有效用户信息');
      }
      _rejectSelf(plain.profileId, ownerUserId);
      if (plain.cookiesJson == null || plain.cookiesJson!.isEmpty) {
        throw AssistException('协助码中缺少登录信息');
      }
      final key = SessionKey.assist(plain.profileId);
      final client = registry.forKey(key);
      await client.importCookiesJson(plain.cookiesJson!);
      final probed = await _probe(client);
      _rejectSelf(probed.id, ownerUserId);
      final identity = AssistIdentity(
        userId: probed.id,
        displayName: probed.name,
        kind: AssistCredentialKind.session,
        deviceId: _nonEmptyDeviceId(plain.deviceId),
        importedAt: clock,
      );
      await _roster.upsert(identity);
      await _store.delete(accountCredKey(probed.id));
      return _syncSharedCoursesBestEffort(probed.id);
    }

    // account
    final user = plain.username?.trim() ?? '';
    final pass = plain.password ?? '';
    if (user.isEmpty || pass.isEmpty) {
      throw AssistException('协助码缺少学号或密码');
    }

    final loginClient = _ephemeralClient();
    final probed = await _loginAccount(
      username: user,
      password: pass,
      targetClient: loginClient,
    );
    _rejectSelf(probed.id, ownerUserId);

    final cookies = await loginClient.exportCookiesJson();
    if (cookies == null || cookies.isEmpty) {
      throw AssistException('登录成功但会话未建立，请重试');
    }
    final assistClient = registry.forKey(SessionKey.assist(probed.id));
    await assistClient.importCookiesJson(cookies);

    final deviceId = _nonEmptyDeviceId(plain.deviceId);
    await _store.write(
      accountCredKey(probed.id),
      jsonEncode({'username': user, 'password': pass}),
    );
    final identity = AssistIdentity(
      userId: probed.id,
      displayName: probed.name,
      kind: AssistCredentialKind.account,
      deviceId: deviceId,
      importedAt: clock,
    );
    await _roster.upsert(identity);
    return _syncSharedCoursesBestEffort(probed.id);
  }

  void _rejectSelf(int profileId, int? ownerUserId) {
    if (ownerUserId != null && ownerUserId > 0 && profileId == ownerUserId) {
      throw AssistException('不能导入当前登录账号自己的凭证');
    }
  }

  Future<AssistIdentity> _syncSharedCoursesBestEffort(int assistUserId) async {
    try {
      return await syncSharedCourses(assistUserId);
    } catch (_) {
      final list = await _roster.list();
      return list.firstWhere(
        (e) => e.userId == assistUserId,
        orElse: () => AssistIdentity(
          userId: assistUserId,
          displayName: '用户',
          kind: AssistCredentialKind.session,
        ),
      );
    }
  }

  /// Owner ∩ assist courses → persist on identity (import / manual refresh).
  Future<AssistIdentity> syncSharedCourses(int assistUserId) async {
    final catalog = courseCatalog;
    if (catalog == null) {
      throw AssistException('未配置课程目录探测，无法同步同课');
    }
    final list = await _roster.list();
    AssistIdentity? identity;
    for (final e in list) {
      if (e.userId == assistUserId) {
        identity = e;
        break;
      }
    }
    if (identity == null) {
      throw AssistException('协助身份不存在');
    }

    identity = await ensureDeviceId(identity);
    await ensureSession(identity);

    final owner = registry.owner();
    await owner.init();
    final ownerCourses = await catalog(owner);
    final ownerIds = {for (final c in ownerCourses) c.id};

    final assistClient = registry.forKey(SessionKey.assist(assistUserId));
    await assistClient.init();
    final assistCourses = await catalog(assistClient);

    String titleFor(AssistSharedCourse c) {
      if (c.title.isNotEmpty) return c.title;
      for (final o in ownerCourses) {
        if (o.id == c.id && o.title.isNotEmpty) return o.title;
      }
      return '';
    }

    final shared = <AssistSharedCourse>[
      for (final c in assistCourses)
        if (ownerIds.contains(c.id))
          AssistSharedCourse(id: c.id, title: titleFor(c)),
    ];

    final updated = identity.copyWith(
      sharedCourses: shared,
      sharedCoursesSyncedAt: DateTime.now().toUtc(),
    );
    await _roster.upsert(updated);
    return updated;
  }

  /// If account cookies died, re-login using stored credentials.
  /// Heals a missing assist [AssistIdentity.deviceId] before probing.
  Future<void> ensureSession(AssistIdentity identity) async {
    identity = await ensureDeviceId(identity);
    final client = registry.forKey(SessionKey.assist(identity.userId));
    await client.init();
    try {
      await _probe(client);
      return;
    } catch (_) {
      if (identity.kind != AssistCredentialKind.account) {
        rethrow;
      }
    }
    final raw = await _store.read(accountCredKey(identity.userId));
    if (raw == null || raw.isEmpty) {
      throw AssistException('登录已失效，且没有可用于重新登录的密码，请重新导入');
    }
    final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    final user = map['username'] as String? ?? '';
    final pass = map['password'] as String? ?? '';
    if (user.isEmpty || pass.isEmpty) {
      throw AssistException('保存的账号信息不完整，请重新导入');
    }
    final loginClient = _ephemeralClient();
    await _loginAccount(
      username: user,
      password: pass,
      targetClient: loginClient,
    );
    final cookies = await loginClient.exportCookiesJson();
    if (cookies == null || cookies.isEmpty) {
      throw AssistException('重新登录失败，请稍后重试');
    }
    await client.importCookiesJson(cookies);
  }

  Future<void> removeIdentity(int userId) async {
    await registry.disposeAssist(userId);
    await _store.delete(accountCredKey(userId));
    await _roster.remove(userId);
  }

  TronHttpClient _ephemeralClient() {
    return TronHttpClient(
      store: SecureStore.memory(),
      sessionKey: SessionKey.owner,
      cookieJar: CookieJar(),
    );
  }

  Future<AssistProfileSnapshot> _loginAccount({
    required String username,
    required String password,
    required TronHttpClient targetClient,
  }) async {
    final custom = accountLogin;
    if (custom != null) {
      return custom(
        username: username,
        password: password,
        targetClient: targetClient,
      );
    }
    await targetClient.init();
    final auth = AuthRepository(
      http: targetClient,
      store: SecureStore.memory(),
    );
    final profile = await auth.signIn(username: username, password: password);
    return AssistProfileSnapshot(id: profile.id, name: profile.name);
  }

  Future<AssistProfileSnapshot> _probe(TronHttpClient client) async {
    final custom = probeProfile;
    if (custom != null) return custom(client);
    final res =
        await client.getUri<Map<String, dynamic>>(TronEndpoints.profile());
    final data = res.data;
    if (data == null) throw AssistException('协助账号验证失败，请重新导入');
    final id = (data['id'] as num?)?.toInt() ?? 0;
    final name = (data['name'] as String?) ??
        (data['user_name'] as String?) ??
        '用户';
    if (id <= 0) throw AssistException('协助账号无效，请重新导入');
    return AssistProfileSnapshot(id: id, name: name);
  }
}
