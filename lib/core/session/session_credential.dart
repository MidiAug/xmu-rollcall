import 'dart:convert';

/// Assist package kinds (ADR-004 dual track).
enum AssistCredentialKind {
  /// TronClass session cookies — lasts until cookie dies.
  session,

  /// IDS username + password — can re-login; revoke by changing password.
  account,
}

extension AssistCredentialKindX on AssistCredentialKind {
  String get wire => switch (this) {
        AssistCredentialKind.session => 'session',
        AssistCredentialKind.account => 'account',
      };

  String get labelZh => switch (this) {
        AssistCredentialKind.session => '临时会话',
        AssistCredentialKind.account => '账号密码',
      };

  static AssistCredentialKind parse(String? raw) {
    switch (raw) {
      case 'account':
        return AssistCredentialKind.account;
      case 'session':
      default:
        return AssistCredentialKind.session;
    }
  }
}

/// Cleartext payload inside an assist token (`xmu2.…`).
class AssistPackagePlain {
  const AssistPackagePlain({
    required this.kind,
    required this.deviceId,
    required this.profileId,
    required this.profileName,
    required this.exportedAt,
    this.cookiesJson,
    this.username,
    this.password,
  });

  final AssistCredentialKind kind;
  final String deviceId;
  final int profileId;
  final String profileName;
  final DateTime exportedAt;
  final String? cookiesJson;
  final String? username;
  final String? password;

  Map<String, dynamic> toJson() => {
        'kind': kind.wire,
        'device_id': deviceId,
        'profile': {'id': profileId, 'name': profileName},
        'exported_at': exportedAt.toUtc().toIso8601String(),
        if (kind == AssistCredentialKind.session)
          'cookies': jsonDecode(cookiesJson ?? '[]'),
        if (kind == AssistCredentialKind.account) ...{
          'username': username,
          'password': password,
        },
      };

  factory AssistPackagePlain.fromJson(Map<String, dynamic> json) {
    final profile = Map<String, dynamic>.from(json['profile'] as Map? ?? {});
    final kind = AssistCredentialKindX.parse(json['kind'] as String?);
    final cookies = json['cookies'];
    return AssistPackagePlain(
      kind: kind,
      deviceId: (json['device_id'] as String?)?.trim() ?? '',
      profileId: (profile['id'] as num?)?.toInt() ?? 0,
      profileName: (profile['name'] as String?) ?? '用户',
      exportedAt: DateTime.tryParse(json['exported_at'] as String? ?? '')
              ?.toUtc() ??
          DateTime.now().toUtc(),
      cookiesJson: cookies == null ? null : jsonEncode(cookies),
      username: json['username'] as String?,
      password: json['password'] as String?,
    );
  }
}

class SessionCredentialException implements Exception {
  SessionCredentialException(this.message);
  final String message;

  @override
  String toString() => message;
}
