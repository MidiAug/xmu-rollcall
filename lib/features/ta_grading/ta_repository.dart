import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:xmu_rollcall/core/network/tron_http_client.dart';
import 'ta_models.dart';
import 'ta_assignment_store.dart';
import 'ta_roster_store.dart';

/// Parent and detail pages share readiness and the resulting session revision.
/// Cached summaries can be read before assisted-session authentication finishes.
class _TaSession {
  _TaSession(this.http, this.prepare) : revision = http.sessionRevision;
  final TronHttpClient http;
  final Future<void> Function()? prepare;
  int revision;
  final rosters = <(int, int), TaRosterSnapshot>{};
  Future<void>? _ready;
  Future<void> ensureReady() => _ready ??= _prepare();
  Future<void> _prepare() async {
    try {
      if (prepare != null) {
        await prepare!();
        revision = http.sessionRevision;
      }
    } catch (_) {
      _ready = null;
      rethrow;
    }
  }
}

class TaGradingRepository {
  TaGradingRepository(
    this.http, {
    DateTime Function()? now,
    int? cacheUserId,
    Future<void> Function()? prepareSession,
  }) : _session = _TaSession(http, prepareSession),
       _disk = cacheUserId == null ? null : TaAssignmentStore(cacheUserId),
       _rosterDisk = cacheUserId == null ? null : TaRosterStore(cacheUserId),
       _now = now ?? DateTime.now;
  TaGradingRepository._(
    this.http,
    this._session,
    this._now,
    this._disk,
    this._rosterDisk,
  );
  final TronHttpClient http;
  final _TaSession _session;
  final TaAssignmentStore? _disk;
  final TaRosterStore? _rosterDisk;
  final DateTime Function() _now;
  final _assignmentCache = <int, TaAssignmentSnapshot>{};
  final _assignmentRequests = <int, Future<List<TaAssignment>>>{};
  final _assignmentAttempts = <int, DateTime>{};
  final _staleCourses = <int>{};
  final _diskReads = <int, Future<void>>{};
  final _diskLoaded = <int>{};
  final _cancel = CancelToken();
  bool get active =>
      !_cancel.isCancelled && http.sessionRevision == _session.revision;

  TaGradingRepository fork() {
    final child = TaGradingRepository._(
      http,
      _session,
      _now,
      _disk,
      _rosterDisk,
    );
    if (!active) child.dispose();
    unawaited(_cancel.whenCancel.then((_) => child.dispose()));
    return child;
  }

  void dispose() {
    _assignmentCache.clear();
    _cancel.cancel('评分页面或账号已变更');
  }

  void checkActive() {
    if (!active) throw StateError('评分页面或账号已变更');
  }

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.https('lnt.xmu.edu.cn', path, query);

  Future<Object?> _get(String path, [Map<String, String>? query]) async {
    checkActive();
    await _session.ensureReady();
    checkActive();
    await http.init();
    final response = await http.getUri<dynamic>(
      _uri(path, query),
      cancelToken: _cancel,
      options: Options(followRedirects: false),
    );
    checkActive();
    if (response.statusCode != 200) throw const FormatException('无法读取助教作业');
    return response.data;
  }

  TaAssignmentSnapshot? cachedAssignments(int courseId) =>
      active ? _assignmentCache[courseId] : null;

  Future<void> restoreAssignments(int courseId) {
    if (_disk == null ||
        _diskLoaded.contains(courseId) ||
        _assignmentCache.containsKey(courseId)) {
      return Future.value();
    }
    return _diskReads[courseId] ??= _restoreAssignments(courseId);
  }

  Future<void> _restoreAssignments(int courseId) async {
    try {
      checkActive();
      final cached = await _disk!.read(courseId);
      checkActive();
      _diskLoaded.add(courseId);
      if (cached != null && !_assignmentCache.containsKey(courseId)) {
        _assignmentCache[courseId] = cached;
      }
    } finally {
      _diskReads.remove(courseId);
    }
  }

  void markAssignmentsStale(int courseId) {
    _staleCourses.add(courseId);
    // A completed grading attempt needs one fresh summary even if the prior
    // list read was recent; this is separate from repeated manual refreshes.
    _assignmentAttempts.remove(courseId);
  }

  Future<List<TaAssignment>> assignments(int courseId, {bool refresh = false}) {
    if (!active) return Future.error(StateError('账号已变更'));
    final pending = _assignmentRequests[courseId];
    if (pending != null) return pending;
    final cached = cachedAssignments(courseId);
    final now = _now();
    if (!refresh &&
        cached != null &&
        !_staleCourses.contains(courseId) &&
        now.difference(cached.checkedAt) < const Duration(minutes: 2)) {
      return Future.value(cached.items);
    }
    final attempted = _assignmentAttempts[courseId];
    if (attempted != null &&
        now.difference(attempted) < const Duration(seconds: 5)) {
      return cached != null
          ? Future.value(cached.items)
          : Future.error(StateError('请稍候再更新作业'));
    }
    _assignmentAttempts[courseId] = now;
    final request = _loadAssignments(courseId);
    _assignmentRequests[courseId] = request;
    return request;
  }

  Future<List<TaAssignment>> _loadAssignments(int courseId) async {
    try {
      final items = List<TaAssignment>.unmodifiable(
        await _fetchAssignments(courseId),
      );
      checkActive();
      final snapshot = TaAssignmentSnapshot(items, _now());
      await _disk?.write(courseId, snapshot);
      checkActive();
      _assignmentCache[courseId] = snapshot;
      _staleCourses.remove(courseId);
      return items;
    } finally {
      _assignmentRequests.remove(courseId);
    }
  }

  Future<List<TaAssignment>> _fetchAssignments(int courseId) async {
    final result = <TaAssignment>[];
    final ids = <int>{};
    var page = 1;
    while (true) {
      final data = taMap(
        await _get('/api/courses/$courseId/homework-activities', {
          'conditions': jsonEncode({
            'itemsSortBy': {'predicate': 'module', 'reverse': false},
          }),
          'page': '$page',
          'page_size': '20',
          'reloadPage': 'false',
        }),
      );
      final pages = data['pages'];
      if (pages is! int || pages < 0 || pages > 100) {
        throw const FormatException('作业分页格式异常');
      }
      for (final row in taRows(data, 'homework_activities')) {
        final item = TaAssignment.parse(row);
        if (!ids.add(item.id)) throw const FormatException('作业分页重复');
        result.add(item);
      }
      if (page >= pages) break;
      page++;
    }
    return result;
  }

  Future<TaAssignment> detail(int courseId, int activityId) async {
    final data = taMap(
      await _get('/api/activities/$activityId', {'sub_course_id': '0'}),
    );
    if (data['course_id'] != courseId || data['id'] != activityId) {
      throw const FormatException('作业与课程不匹配');
    }
    return TaAssignment.parse(data);
  }

  Future<List<TaStudent>> students(int courseId, int activityId) async {
    final roster = taRows(
      await _get('/api/course/$courseId/students', {'ignore_avatar': 'false'}),
      'students',
    );
    final submissions = taRows(
      await _get('/api/homework/$activityId/student-submissions', {
        'need_uploads_size': 'true',
      }),
      'submissions',
    );
    final submitted = <int>{};
    final sizes = <int, int>{};
    for (final row in submissions) {
      final id = taId(taMap(row['created_by'])['id']);
      submitted.add(id);
      final bytes = row['attachments_size'];
      if (bytes != null && (bytes is! int || bytes < 0)) {
        throw const FormatException('附件大小格式异常');
      }
      sizes[id] = bytes as int? ?? 0;
    }
    // Final grades can differ from instructor_score (including students whose
    // submission has no instructor score). Join the complete grade response.
    final scores = <int, double?>{};
    for (final row in taRows(
      await _get('/api/activities/$activityId/homework-scores'),
      'homework_scores',
    )) {
      final id = taId(row['student_id']);
      if (taId(row['activity_id']) != activityId ||
          scores.containsKey(id) ||
          !row.containsKey('final_score')) {
        throw const FormatException('作业成绩关联格式异常');
      }
      scores[id] = taScore(row['final_score']);
    }
    final seen = <int>{};
    return [
      for (final row in roster)
        if (seen.add(taId(row['id'])))
          TaStudent(
            id: taId(row['id']),
            number: row['user_no'] as String,
            name: row['name'] as String,
            submitted: submitted.contains(row['id']),
            score: scores[row['id']],
            scoreChecked: true,
            attachmentBytes: sizes[row['id']] ?? 0,
          )
        else
          throw const FormatException('学生名单重复'),
    ];
  }

  Future<TaRosterSnapshot?> restoreStudents(
    int courseId,
    int activityId,
  ) async {
    checkActive();
    final key = (courseId, activityId);
    final memory = _session.rosters[key];
    if (memory != null) return memory;
    final disk = await _rosterDisk?.read(courseId, activityId);
    checkActive();
    if (disk != null) _session.rosters[key] = disk;
    return disk;
  }

  Future<void> cacheStudents(
    int courseId,
    int activityId,
    List<TaStudent> students, {
    DateTime? checkedAt,
  }) async {
    checkActive();
    final snapshot = TaRosterSnapshot(
      List.unmodifiable(students),
      checkedAt ?? _now(),
    );
    _session.rosters[(courseId, activityId)] = snapshot;
    try {
      await _rosterDisk?.write(courseId, activityId, snapshot);
    } catch (_) {
      // The live server result remains usable when local storage is unavailable.
    }
    checkActive();
  }

  Future<void> cacheStudentScores(
    int courseId,
    int activityId,
    Map<int, double> scores,
  ) async {
    final cached = _session.rosters[(courseId, activityId)];
    if (cached == null || scores.isEmpty) return;
    await cacheStudents(courseId, activityId, [
      for (final s in cached.students)
        if (scores.containsKey(s.id)) s.withScore(scores[s.id]) else s,
    ], checkedAt: cached.checkedAt);
  }

  Future<List<TaScoreRecord>> scoreRecords(
    int activityId,
    int studentId,
  ) async {
    final records = <TaScoreRecord>[];
    var page = 1;
    while (true) {
      final data = taMap(
        await _get(
          '/api/activity/$activityId/submitter/$studentId/score-records',
          {'page': '$page', 'page_size': '20'},
        ),
      );
      final pages = data['pages'];
      if (pages is! int || pages < 0 || pages > 100) {
        throw const FormatException('成绩历史分页异常');
      }
      records.addAll(taRows(data, 'records').map(TaScoreRecord.parse));
      if (page >= pages) break;
      page++;
    }
    records.sort((a, b) {
      final order = b.createdAt.compareTo(a.createdAt);
      return order != 0 ? order : b.id.compareTo(a.id);
    });
    return List.unmodifiable(records);
  }

  Future<double?> currentScore(int activityId, int studentId) async {
    final records = await scoreRecords(activityId, studentId);
    if (records.isEmpty) return null;
    final score = records.first.score;
    if (score == null) throw const FormatException('成绩历史缺少最终分数，请在网页核对');
    return score;
  }

  Future<void> saveScore(int activityId, int studentId, String score) async {
    checkActive();
    await _session.ensureReady();
    checkActive();
    await http.init();
    final response = await http.putUri<dynamic>(
      _uri('/api/course/activities/$activityId/score'),
      data: {'student_id': studentId, 'score': score},
      cancelToken: _cancel,
      beforeSend: () async => checkActive(),
      options: Options(
        contentType: 'application/json;charset=UTF-8',
        followRedirects: false,
        extra: {'retrySafe': false},
        headers: {
          'Origin': 'https://lnt.xmu.edu.cn',
          'Referer': 'https://lnt.xmu.edu.cn/',
        },
      ),
    );
    checkActive();
    final data = taMap(taMap(response.data)['data']);
    if (response.statusCode != 201 ||
        data['activity_id'] != activityId ||
        data['student_id'] != studentId ||
        taScore(data['final_score']) != double.parse(score)) {
      throw const FormatException('保存响应不一致，需重新核对成绩');
    }
  }

  Future<TaZip> zipStatus(int activityId) async => TaZip.parse(
    await _get('/api/zip-status/homework-zip/$activityId', {
      'no-intercept': 'true',
    }),
  );

  Future<void> startZip(
    int activityId,
    List<int> selected,
    List<int> all,
  ) async {
    checkActive();
    if (selected.isEmpty || !selected.every(all.contains)) {
      throw const FormatException('请先选择本课程学生');
    }
    await _session.ensureReady();
    checkActive();
    await http.init();
    final response = await http.postUri<dynamic>(
      _uri('/api/homeworks/$activityId/zip'),
      cancelToken: _cancel,
      data: {
        'ids': selected,
        'all_ids': all,
        'timezone': DateTime.now().timeZoneOffset.inMinutes * -1,
        'column_setting': {
          'showUserNo': true,
          'showDepartment': false,
          'showReviewCount': true,
          'showPeerReviewScore': true,
          'showIntraPeerReviewScore': true,
          'showInterPeerReviewScore': true,
          'showAttachmentsSize': true,
          'showInstructorScore': true,
          'showComment': true,
          'showGrade': false,
        },
      },
      options: Options(
        contentType: Headers.jsonContentType,
        followRedirects: false,
        extra: {'retrySafe': false},
      ),
    );
    checkActive();
    if (response.statusCode != 200) throw const FormatException('打包请求失败');
    taMap(response.data);
  }
}
