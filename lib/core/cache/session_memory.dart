import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Courses seen in owner active list this session (bypass 2h floor for history).
final seenInProgressCourseIdsProvider =
    StateProvider<Set<String>>((ref) => <String>{});
