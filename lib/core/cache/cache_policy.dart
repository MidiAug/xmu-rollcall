/// TTLs and refresh reasons for R-35 cache redesign.
abstract final class CachePolicy {
  /// Enter-SWR floor for todos / course homework / per-course rollcalls.
  static const enterSwrFreshFor = Duration(hours: 2);

  /// Serial gap between course history fetches (KB-01).
  static const courseFetchGap = Duration(milliseconds: 250);

  /// Soft cap when cold-starting a full history scan (no successful fetch yet).
  static const updateAllMaxCourses = 80;
}

enum EnsureFreshReason {
  appear,
  pullToRefresh,
  manualCourse,
}
