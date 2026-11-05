import 'package:xmu_rollcall/core/storage/json_disk_cache.dart';
import 'ta_models.dart';

/// Roster and displayed scores belong to a real identity, course and activity.
class TaRosterStore {
  const TaRosterStore(this.userId);
  final int userId;
  String _key(int courseId, int activityId) =>
      'ta_roster_v1_${userId}_${courseId}_$activityId';

  Future<TaRosterSnapshot?> read(int courseId, int activityId) async {
    try {
      final disk = await JsonDiskCache.readList(_key(courseId, activityId));
      if (disk == null) return null;
      final ids = <int>{};
      final students = <TaStudent>[];
      for (final row in disk.items) {
        final id = taId(row['id']);
        if (!ids.add(id) ||
            row['number'] is! String ||
            row['name'] is! String ||
            row['submitted'] is! bool) {
          return null;
        }
        students.add(
          TaStudent(
            id: id,
            number: row['number'] as String,
            name: row['name'] as String,
            submitted: row['submitted'] as bool,
            score: taScore(row['score']),
            scoreChecked: true,
          ),
        );
      }
      return TaRosterSnapshot(List.unmodifiable(students), disk.fetchedAt);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(int courseId, int activityId, TaRosterSnapshot snapshot) =>
      JsonDiskCache.writeList(_key(courseId, activityId), [
        for (final s in snapshot.students)
          {
            'id': s.id,
            'number': s.number,
            'name': s.name,
            'submitted': s.submitted,
            'score': s.score,
          },
      ], fetchedAt: snapshot.checkedAt);
}
