import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Pending courses seen in the owner active list (bypass 2h floor for history).
/// A successful history fetch consumes the signal; failures keep it for retry.
final seenInProgressCourseIdsProvider = StateProvider<Set<String>>(
  (ref) => <String>{},
);
