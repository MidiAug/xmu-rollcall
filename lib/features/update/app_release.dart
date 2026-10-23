enum UpdateTarget { android, windows }

class UpdateException implements Exception {
  const UpdateException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

/// Stable release identity; build numbers matter to Android's installer.
class AppVersion implements Comparable<AppVersion> {
  const AppVersion(this.major, this.minor, this.patch, [this.build = 0]);
  final int major;
  final int minor;
  final int patch;
  final int build;

  factory AppVersion.parse(String value) {
    final match = RegExp(
      r'^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:\+([1-9]\d*))?$',
    ).firstMatch(value);
    if (match == null) throw const UpdateException('版本格式不受支持，请查看发布页');
    return AppVersion(
      int.parse(match[1]!),
      int.parse(match[2]!),
      int.parse(match[3]!),
      match[4] == null ? 0 : int.parse(match[4]!),
    );
  }

  String get name => '$major.$minor.$patch';
  String get full => '$name+$build';
  int compareRelease(AppVersion other) {
    for (final pair in [
      (major, other.major),
      (minor, other.minor),
      (patch, other.patch),
    ]) {
      final result = pair.$1.compareTo(pair.$2);
      if (result != 0) return result;
    }
    return 0;
  }

  @override
  int compareTo(AppVersion other) {
    final release = compareRelease(other);
    return release == 0 ? build.compareTo(other.build) : release;
  }
}

class ReleaseUpdate {
  const ReleaseUpdate({
    required this.version,
    required this.target,
    required this.notes,
    required this.size,
    required this.sha256,
  });
  static const repository = 'https://github.com/MidiAug/xmu-rollcall';
  static final releasesPage = Uri.parse('$repository/releases/latest');
  final AppVersion version;
  final UpdateTarget target;
  final String notes;
  final int size;
  final String sha256;
  String get fileName =>
      'xmu-rollcall-${version.name}-${target == UpdateTarget.android ? 'android.apk' : 'windows-x64-setup.exe'}';
  Uri get page => Uri.parse('$repository/releases/tag/v${version.name}');
  Uri get downloadUrl => assetUrl(version.name, fileName);
  static Uri assetUrl(String version, String fileName) =>
      Uri.parse('$repository/releases/download/v$version/$fileName');
}
