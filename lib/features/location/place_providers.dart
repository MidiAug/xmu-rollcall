import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/features/campus/campus_summary_providers.dart';
import 'campus_places.dart';
import 'location_models.dart';
import 'location_providers.dart';
import 'place_matching.dart';

final courseRoomsProvider = Provider<List<String>>((ref) {
  final schedule = ref.watch(campusCachedDataProvider).valueOrNull?.schedule;
  if (schedule == null) return const [];
  return {
    for (final slots in schedule.allTables.values)
      for (final slot in slots)
        if (slot.classroom?.trim().isNotEmpty == true) slot.classroom!.trim(),
  }.toList()..sort();
});
final preferredCampusProvider = Provider<Campus>(
  (ref) => preferredCampus(
    ref.watch(courseRoomsProvider),
    ref.watch(savedLocationsProvider),
  ),
);
final unmatchedRoomsProvider = Provider<List<String>>((ref) {
  final custom = ref.watch(savedLocationsProvider);
  return ref
      .watch(courseRoomsProvider)
      .where((room) => matchCoursePlace(room, custom) == null)
      .toList();
});

/// The point is a building reference for this actual classroom, not a room survey.
final courseRoomLocationsProvider = Provider<List<SavedLocation>>((ref) {
  final custom = ref.watch(savedLocationsProvider);
  return [
    for (final room in ref.watch(courseRoomsProvider))
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
final knownLocationsProvider = Provider<List<SavedLocation>>(
  (ref) => [
    ...ref.watch(savedLocationsProvider),
    ...ref.watch(courseRoomLocationsProvider),
  ],
);
