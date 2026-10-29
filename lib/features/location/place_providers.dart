import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/schedule/academic_providers.dart';
import 'package:xmu_rollcall/features/schedule/academic_schedule.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/features/campus/campus_summary_providers.dart';
import 'campus_places.dart';
import 'location_models.dart';
import 'location_providers.dart';
import 'place_matching.dart';
import 'college_campuses.dart';

final _placeScheduleForUserProvider = FutureProvider.autoDispose
    .family<AcademicSchedule?, int>((ref, userId) {
      ref.watch(academicRevisionProvider);
      if (!ref.watch(authControllerProvider).isSignedIn) return null;
      return AcademicScheduleStore.read(userId);
    });

AcademicSchedule? _schedule(Ref ref, int? userId) => userId == null
    ? ref
          .watch(campusCachedDataProvider)
          .whenOrNull(skipLoadingOnReload: false, data: (data) => data.schedule)
    : ref
          .watch(_placeScheduleForUserProvider(userId))
          .whenOrNull(skipLoadingOnReload: false, data: (data) => data);

final courseRoomsForUserProvider = Provider.family<List<String>, int?>((
  ref,
  userId,
) {
  final schedule = _schedule(ref, userId);
  if (schedule == null) return const [];
  return {
    for (final slots in schedule.allTables.values)
      for (final slot in slots)
        if (slot.classroom?.trim().isNotEmpty == true) slot.classroom!.trim(),
  }.toList()..sort();
});

class CoursePlaceGroup {
  const CoursePlaceGroup(this.name, this.rooms, this.courses);
  final String name;
  final List<String> rooms, courses;
}

final coursePlaceGroupsForUserProvider =
    Provider.family<List<CoursePlaceGroup>, int?>((ref, userId) {
      final rooms = ref.watch(
        userId == null
            ? courseRoomsProvider
            : courseRoomsForUserProvider(userId),
      );
      final rows = _schedule(ref, userId)?.rows ?? const <AcademicCourseRow>[];
      final groups = <String, Set<String>>{};
      final names = <String, String>{};
      for (final room in rooms) {
        for (final name in coursePlaceNames(room)) {
          final key = coursePlaceIdentity(name);
          names.putIfAbsent(key, () => name);
          (groups[key] ??= {}).add(room);
        }
      }
      return [
        for (final e in groups.entries)
          CoursePlaceGroup(
            names[e.key]!,
            e.value.toList(),
            {
              for (final row in rows)
                if (e.value.any((room) => room == row.room) &&
                    row.courseName.trim().isNotEmpty)
                  row.courseName,
            }.toList(),
          ),
      ];
    });
final preferredCampusForUserProvider = Provider.family<Campus, int?>(
  (ref, userId) => preferredCampus(
    ref
        .watch(
          userId == null
              ? courseRoomsProvider
              : courseRoomsForUserProvider(userId),
        )
        .expand(coursePlaceNames),
    ref.watch(ref.watch(savedLocationsForUserProvider(userId))),
    collegeCampus: campusForCollege(
      _schedule(ref, userId)?.studentCollege ?? '',
    ),
  ),
);
final unmatchedRoomsForUserProvider = Provider.family<List<String>, int?>((
  ref,
  userId,
) {
  final custom = ref.watch(ref.watch(savedLocationsForUserProvider(userId)));
  return ref
      .watch(
        userId == null
            ? coursePlaceGroupsProvider
            : coursePlaceGroupsForUserProvider(userId),
      )
      .map((g) => g.name)
      .where((room) => matchCoursePlace(room, custom) == null)
      .toList();
});

/// The point is a building reference for this actual classroom, not a room survey.
final courseRoomLocationsForUserProvider =
    Provider.family<List<SavedLocation>, int?>((ref, userId) {
      final custom = ref.watch(
        ref.watch(savedLocationsForUserProvider(userId)),
      );
      return [
        for (final room
            in ref
                .watch(
                  userId == null
                      ? coursePlaceGroupsProvider
                      : coursePlaceGroupsForUserProvider(userId),
                )
                .map((g) => g.name))
          if (matchCoursePlace(room, custom) case final place?)
            if (place.id.startsWith('xmu:'))
              SavedLocation(
                id: 'room:${Uri.encodeComponent(room)}',
                note: room,
                latitude: place.latitude,
                longitude: place.longitude,
                accuracy: place.accuracy,
                createdAt: place.createdAt,
              ),
      ];
    });
final knownLocationsForUserProvider =
    Provider.family<List<SavedLocation>, int?>(
      (ref, userId) => [
        ...ref.watch(ref.watch(savedLocationsForUserProvider(userId))),
        ...teachingPlaces.map((p) => p.saved),
        ...ref.watch(
          userId == null
              ? courseRoomLocationsProvider
              : courseRoomLocationsForUserProvider(userId),
        ),
      ],
    );

final courseRoomsProvider = Provider<List<String>>(
  (ref) => ref.watch(courseRoomsForUserProvider(null)),
);

final coursePlaceGroupsProvider = Provider<List<CoursePlaceGroup>>(
  (ref) => ref.watch(coursePlaceGroupsForUserProvider(null)),
);

final preferredCampusProvider = Provider<Campus>(
  (ref) => ref.watch(preferredCampusForUserProvider(null)),
);

final unmatchedRoomsProvider = Provider<List<String>>(
  (ref) => ref.watch(unmatchedRoomsForUserProvider(null)),
);

final courseRoomLocationsProvider = Provider<List<SavedLocation>>(
  (ref) => ref.watch(courseRoomLocationsForUserProvider(null)),
);

final knownLocationsProvider = Provider<List<SavedLocation>>(
  (ref) => ref.watch(knownLocationsForUserProvider(null)),
);
