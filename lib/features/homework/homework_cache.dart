import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/core/storage/json_disk_cache.dart';
import 'homework_models.dart';

List<HomeworkItem> mergeHomeworkItems(
  Iterable<HomeworkItem> sources,
  CourseCatalogSnapshot? catalog,
) {
  final courses = {
    for (final c in catalog?.courses ?? <CatalogCourse>[]) c.id: c,
  };
  final items = <String, HomeworkItem>{};
  for (var item in sources) {
    final course = courses['${item.courseId}'];
    if (catalog != null &&
        item.courseId != null &&
        (course == null || course.isTeaching)) {
      continue;
    }
    if (item.courseName.isEmpty && course != null) {
      item = item.copyWith(courseName: course.title);
    }
    items['${item.courseId}/${item.id}'] = item;
  }
  return items.values.toList();
}

/// Same sources as the overview, without mounting any network providers.
Future<({List<HomeworkItem> items, bool hasCache})> readCachedHomework(
  int uid,
  CourseCatalogSnapshot? catalog,
) async {
  final todos = await JsonDiskCache.readList('homework_todos_$uid');
  var hasCache = todos != null;
  final items = [
    for (final row in todos?.items ?? <Map<String, dynamic>>[])
      HomeworkItem.fromJson(row),
  ];
  for (final course
      in catalog?.courses.where((c) => !c.isTeaching) ??
          <CatalogCourse>[]) {
    final cid = int.tryParse(course.id);
    if (cid == null) continue;
    final disk = await JsonDiskCache.readList('course_homework_${uid}_$cid');
    hasCache |= disk != null;
    for (final row in disk?.items ?? <Map<String, dynamic>>[]) {
      items.add(
        HomeworkItem.fromJson(
          row,
        ).copyWith(courseId: cid, courseName: course.title),
      );
    }
  }
  return (items: mergeHomeworkItems(items, catalog), hasCache: hasCache);
}
