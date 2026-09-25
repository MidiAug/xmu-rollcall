class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    this.email,
    this.raw = const {},
  });

  final int id;
  final String name;
  final String? email;
  final Map<String, dynamic> raw;

  /// Student number / user_no when present; never prefer internal numeric id.
  String? get studentNo {
    for (final k in const [
      'user_no',
      'userNo',
      'student_number',
      'student_no',
      'user_code',
    ]) {
      final v = raw[k];
      if (v == null) continue;
      final s = '$v'.trim();
      if (s.isNotEmpty) return s;
    }
    return null;
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?) ??
          (json['user_name'] as String?) ??
          '用户',
      email: json['email'] as String?,
      raw: json,
    );
  }
}

enum AuthStatus { unknown, signedOut, signedIn, loading }

class AuthState {
  const AuthState({
    required this.status,
    this.profile,
    this.errorMessage,
  });

  final AuthStatus status;
  final UserProfile? profile;
  final String? errorMessage;

  bool get isSignedIn => status == AuthStatus.signedIn && profile != null;

  AuthState copyWith({
    AuthStatus? status,
    UserProfile? profile,
    String? errorMessage,
    bool clearError = false,
    bool clearProfile = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      profile: clearProfile ? null : (profile ?? this.profile),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
