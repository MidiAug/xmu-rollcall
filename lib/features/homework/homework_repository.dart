import 'package:dio/dio.dart';
import 'package:xmu_rollcall/core/network/tron_endpoints.dart';
import 'package:xmu_rollcall/core/network/tron_http_client.dart';
import 'package:xmu_rollcall/core/network/rate_limiter.dart';
import 'package:xmu_rollcall/features/homework/homework_models.dart';
import 'package:xmu_rollcall/features/homework/homework_submission.dart';

class HomeworkRepository {
  HomeworkRepository({required this.http});

  final TronHttpClient http;

  static const maxHomeworkPages = 50;

  Future<HomeworkSubmissionState> fetchSubmission({
    required int activityId,
    required int studentId,
    CancelToken? cancelToken,
  }) async {
    await http.init();
    final response = await http.getUri<dynamic>(
      TronEndpoints.homeworkSubmissions(
        activityId: activityId,
        studentId: studentId,
      ),
      priority: RequestPriority.background,
      cancelToken: cancelToken,
    );
    if (response.statusCode != 200) {
      throw StateError('无法更新提交状态 (${response.statusCode})');
    }
    return HomeworkSubmissionState.parse(response.data);
  }

  Future<List<HomeworkItem>> fetchTodos() async {
    final r = await fetchTodosDetailed();
    return r.items;
  }

  /// Todos plus parse diagnostics for logging (denylist_v1).
  Future<HomeworkTodosFetch> fetchTodosDetailed() async {
    await http.init();
    final res = await http.getUri<dynamic>(TronEndpoints.todos());
    if ((res.statusCode ?? 0) != 200) {
      throw StateError('拉取待办失败 (${res.statusCode})');
    }
    const candidates = [
      'todo_list',
      'todos',
      'data',
      'items',
      'list',
      'results',
    ];
    final diag = <String, dynamic>{};
    final data = res.data;
    String? listKeyHit;
    List<dynamic> list = const [];
    if (data is List) {
      listKeyHit = '(root_list)';
      list = data;
      diag['topKeys'] = <String>[];
    } else if (data is Map) {
      final m = Map<String, dynamic>.from(data);
      diag['topKeys'] = (m.keys.map((k) => k.toString()).toList()..sort());
      for (final k in candidates) {
        final v = m[k];
        if (v is List) {
          listKeyHit = k;
          list = v;
          break;
        }
      }
    }
    if (listKeyHit == null) throw const FormatException('待办列表格式不支持');
    diag['listKeyHit'] = listKeyHit;
    final out = <HomeworkItem>[];
    final sampleIds = <int>[];
    for (final raw in list) {
      if (raw is! Map) continue;
      final item = HomeworkItem.fromJson(Map<String, dynamic>.from(raw));
      if (item.id == 0 && item.title.isEmpty) continue;
      out.add(item);
      if (sampleIds.length < 5 && item.id != 0) sampleIds.add(item.id);
    }
    out.sort(_byDue);
    diag['sampleIds'] = sampleIds;
    return HomeworkTodosFetch(items: out, diag: diag);
  }

  Future<List<HomeworkItem>> fetchCourseHomework(int courseId) async {
    await http.init();
    final all = <HomeworkItem>[];
    var page = 1;
    var totalPages = 1;
    while (page <= totalPages && page <= maxHomeworkPages) {
      final res = await http.getUri<dynamic>(
        TronEndpoints.courseHomeworkActivities(
          courseId: courseId,
          page: page,
          pageSize: 100,
        ),
        priority: RequestPriority.background,
      );
      if ((res.statusCode ?? 0) != 200) {
        throw StateError('拉取课程作业失败 (${res.statusCode})');
      }
      final data = res.data;
      if (data is Map) {
        final m = Map<String, dynamic>.from(data);
        final pages = m['pages'];
        if (pages is num) {
          totalPages = pages.toInt().clamp(1, maxHomeworkPages);
        } else {
          final total = m['total'];
          final pageSize = m['page_size'] ?? m['pageSize'] ?? 100;
          if (total is num && pageSize is num && pageSize > 0) {
            totalPages =
                ((total.toInt() + pageSize.toInt() - 1) ~/ pageSize.toInt())
                    .clamp(1, maxHomeworkPages);
          }
        }
      }
      final list = _unwrapList(data, const [
        'homework_activities',
        'activities',
        'data',
        'items',
        'list',
        'results',
      ]);
      if (list.isEmpty) break;
      for (final raw in list) {
        if (raw is! Map) continue;
        final map = Map<String, dynamic>.from(raw);
        map.putIfAbsent('course_id', () => courseId);
        final item = HomeworkItem.fromJson(map);
        if (item.id == 0 && item.title.isEmpty) continue;
        all.add(item);
      }
      page++;
      if (page <= totalPages) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    }
    all.sort(_byDue);
    return all;
  }

  Future<HomeworkItem> fetchDetail({
    required int activityId,
    int? courseId,
  }) async {
    await http.init();
    if (courseId != null && courseId > 0) {
      final res = await http.getUri<dynamic>(
        TronEndpoints.courseHomeworkDetail(
          courseId: courseId,
          activityId: activityId,
        ),
      );
      final code = res.statusCode ?? 0;
      if (code == 200) {
        return _detailFromPayload(res.data, courseId: courseId);
      }
      if (code != 404) {
        throw StateError('拉取作业详情失败 ($code)');
      }
    }
    final fallback = await http.getUri<dynamic>(
      TronEndpoints.activityDetail(activityId),
    );
    if ((fallback.statusCode ?? 0) != 200) {
      throw StateError('拉取作业详情失败 (${fallback.statusCode})');
    }
    return _detailFromPayload(fallback.data, courseId: courseId);
  }

  HomeworkItem _detailFromPayload(dynamic data, {int? courseId}) {
    Map<String, dynamic> map;
    if (data is Map) {
      map = Map<String, dynamic>.from(data);
      for (final key in const [
        'homework_activity',
        'activity',
        'data',
        'item',
      ]) {
        final nested = map[key];
        if (nested is Map) {
          map = Map<String, dynamic>.from(nested);
          break;
        }
      }
    } else {
      map = const {};
    }
    if (courseId != null) {
      map.putIfAbsent('course_id', () => courseId);
    }
    return HomeworkItem.fromJson(map);
  }

  List<dynamic> _unwrapList(dynamic payload, List<String> keys) {
    if (payload is List) return payload;
    if (payload is! Map) throw const FormatException('课程作业列表格式不支持');
    final m = Map<String, dynamic>.from(payload);
    for (final k in keys) {
      final v = m[k];
      if (v is List) return v;
    }
    throw const FormatException('课程作业列表格式不支持');
  }

  int _byDue(HomeworkItem a, HomeworkItem b) {
    final ad = a.dueAt;
    final bd = b.dueAt;
    if (ad == null && bd == null) return a.title.compareTo(b.title);
    if (ad == null) return 1;
    if (bd == null) return -1;
    return ad.compareTo(bd);
  }
}

class HomeworkTodosFetch {
  const HomeworkTodosFetch({required this.items, required this.diag});

  final List<HomeworkItem> items;
  final Map<String, dynamic> diag;
}
