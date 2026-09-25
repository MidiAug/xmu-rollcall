import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/storage/json_disk_cache.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';

/// Per-course rollcall disk envelope (R-35 §3). Shared by history + session prior.
enum CourseRollcallsFetchState {
  /// Never had a successful response.
  neverChecked,

  /// Last response was success with zero records.
  emptySuccess,

  /// Last response was success with ≥1 records.
  hasRecords,

  /// Last attempt failed; [CourseRollcallsSnapshot.records] may still hold old data.
  failed,
}

class CourseRollcallsSnapshot {
  const CourseRollcallsSnapshot({
    required this.courseId,
    required this.courseTitle,
    this.lastSuccessfulFetch,
    this.error,
    this.records = const [],
    this.truncated = false,
  });

  final String courseId;
  final String courseTitle;
  final DateTime? lastSuccessfulFetch;
  final String? error;
  final List<CourseRollcallRecord> records;
  final bool truncated;

  CourseRollcallsFetchState get fetchState {
    if (error != null && error!.isNotEmpty) {
      return CourseRollcallsFetchState.failed;
    }
    if (lastSuccessfulFetch == null) {
      return CourseRollcallsFetchState.neverChecked;
    }
    if (records.isEmpty) return CourseRollcallsFetchState.emptySuccess;
    return CourseRollcallsFetchState.hasRecords;
  }

  bool isFresh(Duration floor, {DateTime? now}) {
    final at = lastSuccessfulFetch;
    if (at == null) return false;
    final age = (now ?? DateTime.now()).difference(at);
    if (age.isNegative) return true;
    return age < floor;
  }

  Map<String, dynamic> toJson() => {
        'courseId': courseId,
        'courseTitle': courseTitle,
        if (lastSuccessfulFetch != null)
          'lastSuccessfulFetch': lastSuccessfulFetch!.toIso8601String(),
        if (error != null) 'error': error,
        'records': [for (final r in records) r.toJson()],
        'truncated': truncated,
      };

  factory CourseRollcallsSnapshot.fromJson(Map<String, dynamic> j) {
    final raw = j['records'];
    final records = <CourseRollcallRecord>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) {
          records.add(
            CourseRollcallRecord.fromJson(Map<String, dynamic>.from(e)),
          );
        }
      }
    }
    return CourseRollcallsSnapshot(
      courseId: '${j['courseId'] ?? ''}',
      courseTitle: j['courseTitle'] as String? ?? '',
      lastSuccessfulFetch: DateTime.tryParse(
        j['lastSuccessfulFetch'] as String? ?? '',
      ),
      error: j['error'] as String?,
      records: records,
      truncated: j['truncated'] as bool? ?? false,
    );
  }

  CourseRollcallsSnapshot copyWith({
    String? courseTitle,
    DateTime? lastSuccessfulFetch,
    String? error,
    bool clearError = false,
    List<CourseRollcallRecord>? records,
    bool? truncated,
  }) {
    return CourseRollcallsSnapshot(
      courseId: courseId,
      courseTitle: courseTitle ?? this.courseTitle,
      lastSuccessfulFetch: lastSuccessfulFetch ?? this.lastSuccessfulFetch,
      error: clearError ? null : (error ?? this.error),
      records: records ?? this.records,
      truncated: truncated ?? this.truncated,
    );
  }
}

/// Disk IO for `rollcalls_{userId}_{courseId}` (under [JsonDiskCache.keyPrefix]).
abstract final class CourseRollcallsStore {
  static String suffix(int userId, String courseId) =>
      'rollcalls_${userId}_$courseId';

  static Future<CourseRollcallsSnapshot?> read(
    int userId,
    String courseId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(JsonDiskCache.key(suffix(userId, courseId)));
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return CourseRollcallsSnapshot.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(int userId, CourseRollcallsSnapshot snap) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      JsonDiskCache.key(suffix(userId, snap.courseId)),
      jsonEncode(snap.toJson()),
    );
  }

  /// Success path: update [lastSuccessfulFetch], clear error, replace records.
  static Future<CourseRollcallsSnapshot> writeSuccess({
    required int userId,
    required String courseId,
    required String courseTitle,
    required List<CourseRollcallRecord> records,
    bool truncated = false,
    DateTime? at,
  }) async {
    final snap = CourseRollcallsSnapshot(
      courseId: courseId,
      courseTitle: courseTitle,
      lastSuccessfulFetch: at ?? DateTime.now(),
      records: records,
      truncated: truncated,
    );
    await write(userId, snap);
    return snap;
  }

  /// Failure path: keep previous records; set error; do not touch lastSuccessfulFetch.
  static Future<CourseRollcallsSnapshot> writeFailure({
    required int userId,
    required String courseId,
    required String courseTitle,
    required Object error,
    CourseRollcallsSnapshot? previous,
  }) async {
    final snap = (previous ??
            CourseRollcallsSnapshot(
              courseId: courseId,
              courseTitle: courseTitle,
            ))
        .copyWith(
      courseTitle: courseTitle.isNotEmpty
          ? courseTitle
          : previous?.courseTitle,
      error: '$error',
    );
    await write(userId, snap);
    return snap;
  }

  /// Rows for the flat history list (success empty → placeholder; never → status row).
  static List<CourseRollcallRecord> toHistoryRows(CourseRollcallsSnapshot snap) {
    switch (snap.fetchState) {
      case CourseRollcallsFetchState.hasRecords:
        return [
          for (final r in snap.records)
            r.courseTitle.isEmpty && snap.courseTitle.isNotEmpty
                ? CourseRollcallRecord(
                    courseId: r.courseId,
                    courseTitle: snap.courseTitle,
                    rollcallId: r.rollcallId,
                    rollcallTime: r.rollcallTime,
                    typeLabel: r.typeLabel,
                    signedStatus: r.signedStatus,
                    platformStatus: r.platformStatus,
                    detail: r.detail,
                  )
                : r,
        ];
      case CourseRollcallsFetchState.emptySuccess:
        return [
          CourseRollcallRecord(
            courseId: snap.courseId,
            courseTitle: snap.courseTitle,
            rollcallId: '-',
            rollcallTime: null,
            typeLabel: '-',
            signedStatus: '本课暂无签到记录',
            platformStatus: '-',
          ),
        ];
      case CourseRollcallsFetchState.neverChecked:
        return [
          CourseRollcallRecord(
            courseId: snap.courseId,
            courseTitle: snap.courseTitle,
            rollcallId: '-',
            rollcallTime: null,
            typeLabel: '-',
            signedStatus: '尚未更新',
            platformStatus: '-',
            detail: 'enter_unchecked',
          ),
        ];
      case CourseRollcallsFetchState.failed:
        if (snap.records.isNotEmpty) {
          return [
            ...toHistoryRows(
              snap.copyWith(clearError: true),
            ),
            CourseRollcallRecord(
              courseId: snap.courseId,
              courseTitle: snap.courseTitle,
              rollcallId: '-',
              rollcallTime: null,
              typeLabel: '-',
              signedStatus: '本课更新失败',
              platformStatus: '-',
              detail: snap.error ?? '',
            ),
          ];
        }
        return [
          CourseRollcallRecord(
            courseId: snap.courseId,
            courseTitle: snap.courseTitle,
            rollcallId: '-',
            rollcallTime: null,
            typeLabel: '-',
            signedStatus: '本课更新失败',
            platformStatus: '-',
            detail: snap.error ?? '',
          ),
        ];
    }
  }
}
