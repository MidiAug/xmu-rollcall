import 'dart:convert';

/// Cleartext payload inside an encrypted session credential package.
class SessionCredentialPlain {
  const SessionCredentialPlain({
    required this.cookiesJson,
    required this.profileId,
    required this.profileName,
    required this.exportedAt,
    this.suggestedExpiresAt,
  });

  final String cookiesJson;
  final int profileId;
  final String profileName;
  final DateTime exportedAt;
  final DateTime? suggestedExpiresAt;

  bool isSuggestedExpired([DateTime? now]) {
    final exp = suggestedExpiresAt;
    if (exp == null) return false;
    return (now ?? DateTime.now().toUtc()).isAfter(exp.toUtc());
  }

  Map<String, dynamic> toJson() => {
        'cookies': jsonDecode(cookiesJson),
        'profile': {'id': profileId, 'name': profileName},
        'exported_at': exportedAt.toUtc().toIso8601String(),
        if (suggestedExpiresAt != null)
          'suggested_expires_at':
              suggestedExpiresAt!.toUtc().toIso8601String(),
      };

  factory SessionCredentialPlain.fromJson(Map<String, dynamic> json) {
    final profile = Map<String, dynamic>.from(json['profile'] as Map? ?? {});
    final cookies = json['cookies'];
    return SessionCredentialPlain(
      cookiesJson: jsonEncode(cookies ?? []),
      profileId: (profile['id'] as num?)?.toInt() ?? 0,
      profileName: (profile['name'] as String?) ?? '用户',
      exportedAt: DateTime.tryParse(json['exported_at'] as String? ?? '')
              ?.toUtc() ??
          DateTime.now().toUtc(),
      suggestedExpiresAt:
          DateTime.tryParse(json['suggested_expires_at'] as String? ?? '')
              ?.toUtc(),
    );
  }
}

class SessionCredentialException implements Exception {
  SessionCredentialException(this.message);
  final String message;

  @override
  String toString() => message;
}
