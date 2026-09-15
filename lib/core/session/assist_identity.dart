/// Metadata for an imported assist session (cookies live in SessionKey jar).
class AssistIdentity {
  const AssistIdentity({
    required this.userId,
    required this.displayName,
    this.importedAt,
    this.suggestedExpiresAt,
  });

  final int userId;
  final String displayName;
  final DateTime? importedAt;
  final DateTime? suggestedExpiresAt;

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'displayName': displayName,
        if (importedAt != null)
          'importedAt': importedAt!.toUtc().toIso8601String(),
        if (suggestedExpiresAt != null)
          'suggestedExpiresAt':
              suggestedExpiresAt!.toUtc().toIso8601String(),
      };

  factory AssistIdentity.fromJson(Map<String, dynamic> json) {
    return AssistIdentity(
      userId: (json['userId'] as num?)?.toInt() ?? 0,
      displayName: (json['displayName'] as String?) ?? '用户',
      importedAt:
          DateTime.tryParse(json['importedAt'] as String? ?? '')?.toUtc(),
      suggestedExpiresAt:
          DateTime.tryParse(json['suggestedExpiresAt'] as String? ?? '')
              ?.toUtc(),
    );
  }
}
