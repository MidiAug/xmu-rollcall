import 'package:xmu_rollcall/core/storage/json_disk_cache.dart';
import 'ta_models.dart';

/// Summaries only. Real user IDs isolate owner logins and assisted accounts.
class TaAssignmentStore {
  const TaAssignmentStore(this.userId);
  final int userId;
  String _key(int courseId) => 'ta_assignments_v1_${userId}_$courseId';

  Future<TaAssignmentSnapshot?> read(int courseId) async {
    try {
      final disk = await JsonDiskCache.readList(_key(courseId));
      if (disk == null || disk.items.length != 1) return null;
      final data = disk.items.single;
      if (data['course_id'] != courseId) return null;
      final ids = <int>{};
      final items = <TaAssignment>[];
      for (final row in taRows(data, 'assignments')) {
        final id = taId(row['id']);
        final title = row['title'];
        final expected = row['expected'];
        final submitted = row['submitted'];
        final graded = row['graded'];
        if (!ids.add(id) ||
            title is! String ||
            expected is! int ||
            expected < 0 ||
            submitted is! int ||
            submitted < 0 ||
            graded is! int ||
            graded < 0) {
          return null;
        }
        final startTime = row['start_time'] is String
            ? DateTime.tryParse(row['start_time'] as String)
            : null;
        final endTime = row['end_time'] is String
            ? DateTime.tryParse(row['end_time'] as String)
            : null;
        items.add(
          TaAssignment(
            id: id,
            title: title,
            expected: expected,
            submitted: submitted,
            graded: graded,
            startTime: startTime,
            endTime: endTime,
          ),
        );
      }
      return TaAssignmentSnapshot(List.unmodifiable(items), disk.fetchedAt);
    } catch (_) {
      // An unreadable local mirror is a cache miss, never a partial roster.
      return null;
    }
  }

  Future<void> write(int courseId, TaAssignmentSnapshot snapshot) =>
      JsonDiskCache.writeList(_key(courseId), [
        {
          'course_id': courseId,
          'assignments': [
            for (final item in snapshot.items)
              {
                'id': item.id,
                'title': item.title,
                'expected': item.expected,
                'submitted': item.submitted,
                'graded': item.graded,
                'start_time': item.startTime?.toUtc().toIso8601String(),
                'end_time': item.endTime?.toUtc().toIso8601String(),
              },
          ],
        },
      ], fetchedAt: snapshot.checkedAt);
}
