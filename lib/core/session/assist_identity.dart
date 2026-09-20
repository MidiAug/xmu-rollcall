import 'package:xmu_rollcall/core/session/session_credential.dart';

/// Metadata for an imported assist identity (cookies live in SessionKey jar).
class AssistIdentity {
  const AssistIdentity({
    required this.userId,
    required this.displayName,
    required this.kind,
    this.deviceId,
    this.importedAt,
  });

  final int userId;
  final String displayName;
  final AssistCredentialKind kind;
  final String? deviceId;
  final DateTime? importedAt;

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'displayName': displayName,
        'kind': kind.wire,
        if (deviceId != null && deviceId!.isNotEmpty) 'deviceId': deviceId,
        if (importedAt != null)
          'importedAt': importedAt!.toUtc().toIso8601String(),
      };

  factory AssistIdentity.fromJson(Map<String, dynamic> json) {
    return AssistIdentity(
      userId: (json['userId'] as num?)?.toInt() ?? 0,
      displayName: (json['displayName'] as String?) ?? '用户',
      kind: AssistCredentialKindX.parse(json['kind'] as String?),
      deviceId: json['deviceId'] as String?,
      importedAt:
          DateTime.tryParse(json['importedAt'] as String? ?? '')?.toUtc(),
    );
  }
}
