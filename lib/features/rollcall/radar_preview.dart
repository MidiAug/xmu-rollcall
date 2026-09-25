import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/app_page_routes.dart';
import 'package:xmu_rollcall/features/location/location_models.dart';
import 'package:xmu_rollcall/features/location/location_providers.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_answer_page.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';

/// Debug-only fixtures for opening the radar answer page without a live session.
enum RadarPreviewScenario { empty, prefPlace, prefDevice }

const _previewCourseId = 'preview-course-111857';
const _previewCourseTitle = '工程伦理（预览）';
const _previewPlaceNote = '翔安教学楼';
const _previewLat = 24.60696;
const _previewLng = 118.30180;

RollcallItem radarPreviewItem() => const RollcallItem(
  rollcallId: -9001,
  courseTitle: _previewCourseTitle,
  createdByName: '预览发起人',
  type: RollcallType.radar,
  status: 'on_call',
  rollcallStatus: 'on_call',
  isExpired: false,
  scored: false,
  raw: {'course_id': _previewCourseId},
);

Future<void> openRadarPreview(
  BuildContext context,
  WidgetRef ref,
  RadarPreviewScenario scenario,
) async {
  assert(kDebugMode, 'radar preview is debug-only');
  if (!kDebugMode) return;

  final places = ref.read(savedLocationsProvider.notifier);
  final prefs = ref.read(courseRadarDefaultsProvider.notifier);

  switch (scenario) {
    case RadarPreviewScenario.empty:
      break;
    case RadarPreviewScenario.prefPlace:
      SavedLocation? existing;
      for (final e in ref.read(savedLocationsProvider)) {
        if (e.note == _previewPlaceNote &&
            (e.latitude - _previewLat).abs() < 0.0002 &&
            (e.longitude - _previewLng).abs() < 0.0002) {
          existing = e;
          break;
        }
      }
      final place =
          existing ??
          await places.add(
            note: _previewPlaceNote,
            latitude: _previewLat,
            longitude: _previewLng,
          );
      await prefs.rememberSuccess(
        courseTitle: _previewCourseTitle,
        courseId: _previewCourseId,
        latitude: place.latitude,
        longitude: place.longitude,
        accuracy: place.accuracy,
        placeId: place.id,
        obtainedVia: RadarObtainedVia.place,
        labelSnapshot: place.note,
      );
    case RadarPreviewScenario.prefDevice:
      await prefs.rememberSuccess(
        courseTitle: _previewCourseTitle,
        courseId: _previewCourseId,
        latitude: _previewLat,
        longitude: _previewLng,
        accuracy: 18,
        obtainedVia: RadarObtainedVia.device,
      );
  }

  if (!context.mounted) return;
  await AppPageRoutes.push<void>(
    context,
    RollcallAnswerPage(item: radarPreviewItem(), previewMode: true),
  );
}
