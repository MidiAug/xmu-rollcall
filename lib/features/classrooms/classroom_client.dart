import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:xmu_rollcall/core/network/rate_limiter.dart';
import 'package:xmu_rollcall/core/network/tron_endpoints.dart';
import 'package:xmu_rollcall/features/auth/ids_auth.dart';
import 'classroom_models.dart';
export 'classroom_models.dart';

class ClassroomWriteUncertain extends FormatException {
  const ClassroomWriteUncertain() : super('提交结果尚未确认，请先查看我的记录，勿重复提交');
}

class ClassroomClient {
  ClassroomClient({Dio? dio, RateLimiter? limiter})
    : dio = dio ?? Dio(),
      limiter = limiter ?? RateLimiter() {
    this.dio.interceptors.add(CookieManager(jar));
    this.dio.options.connectTimeout = const Duration(seconds: 20);
    this.dio.options.receiveTimeout = const Duration(seconds: 30);
  }
  static final origin = Uri.parse('https://eclass.xmu.edu.cn');
  final Dio dio;
  final RateLimiter limiter;
  final jar = CookieJar();
  Future<bool> Function()? identityGuard;
  String? _token, _username;
  ClassroomUser? user;
  Future<void>? _connecting;
  bool _writing = false;
  Future<void> _guard() async {
    if (identityGuard != null && !await identityGuard!()) {
      throw StateError('账号已切换');
    }
  }

  Future<Response<dynamic>> _hop(
    String method,
    Uri uri, {
    Object? data,
    String? contentType,
    Map<String, String>? extraHeaders,
  }) async {
    if (uri.scheme != 'https' ||
        !{'eclass.xmu.edu.cn', 'ids.xmu.edu.cn'}.contains(uri.host)) {
      throw const FormatException('教室登录地址异常');
    }
    final result = await limiter.schedule(() async {
      await _guard();
      return dio.requestUri<dynamic>(
        uri,
        data: data,
        options: Options(
          method: method,
          contentType: contentType,
          responseType: ResponseType.plain,
          followRedirects: false,
          validateStatus: (s) => s != null && s < 500,
          headers: {
            'User-Agent': TronEndpoints.userAgent,
            ...?extraHeaders,
            if (uri.host == origin.host && _token != null)
              'Authorization': 'Bearer $_token',
          },
        ),
      );
    });
    await _guard();
    return result;
  }

  Future<void> connect({
    required String username,
    String? password,
    CookieJar? sso,
  }) {
    if (_username != null && _username != username) {
      throw const FormatException('教室会话与所选账号不一致');
    }
    return _connecting ??= _connect(
      username,
      password,
      sso,
    ).whenComplete(() => _connecting = null);
  }

  Future<void> _connect(
    String username,
    String? password,
    CookieJar? sso,
  ) async {
    if (_token != null) return;
    final ids = Uri.parse('https://ids.xmu.edu.cn/authserver/login');
    if (sso != null) {
      await jar.saveFromResponse(ids, await sso.loadForRequest(ids));
    }
    var uri = origin.resolve('/cas/login');
    bool submitted = false;
    for (var i = 0; i < 16; i++) {
      var query = uri.queryParameters;
      if (uri.fragment.contains('?')) {
        query = {
          ...query,
          ...Uri.splitQueryString(
            uri.fragment.substring(uri.fragment.indexOf('?') + 1),
          ),
        };
      }
      final token = query['access_token'];
      if (uri.host == origin.host && token != null && token.isNotEmpty) {
        _token = token;
        try {
          final v = classroomMap(await _api('/currentUser'));
          user = ClassroomUser.fromJson(v);
          if (user!.code != username) {
            throw const FormatException('教室登录身份不匹配，请重新登录');
          }
          _username = username;
          return;
        } catch (_) {
          _token = null;
          user = null;
          rethrow;
        }
      }
      final response = await _hop('GET', uri);
      final html = '${response.data ?? ''}';
      if (uri.host == ids.host && html.contains('pwdEncryptSalt')) {
        if (submitted || password == null) {
          throw const FormatException('请重新登录所选账号以连接厦大教室');
        }
        submitted = true;
        uri = await IdsAuth(
          _hop,
        ).submit(url: uri, html: html, username: username, password: password);
        continue;
      }
      final location = response.headers.value('location');
      if (location == null ||
          !{301, 302, 303, 307, 308}.contains(response.statusCode)) {
        throw const FormatException('厦大教室登录未完成，请更新后重试');
      }
      uri = uri.resolve(location);
    }
    throw const FormatException('教室登录跳转过多');
  }

  Future<Object?> _api(
    String path, {
    Map<String, dynamic>? query,
    Object? body,
    bool write = false,
    String? method,
  }) async {
    if (write && _writing) throw const FormatException('正在提交，请勿重复操作');
    if (write) _writing = true;
    try {
      final response = await _hop(
        method ?? (body == null ? 'GET' : 'POST'),
        origin
            .resolve('/api$path')
            .replace(queryParameters: query?.map((k, v) => MapEntry(k, '$v'))),
        data: body,
        contentType: body == null ? null : Headers.jsonContentType,
        extraHeaders: path == '/customization/addBook'
            ? {'x-platform': 'wecom'}
            : null,
      );
      if (response.statusCode == 401) {
        _token = null;
        throw const FormatException('教室会话已过期，请更新');
      }
      if (response.statusCode != 200) {
        if (write) throw const ClassroomWriteUncertain();
        throw const FormatException('厦大教室暂时不可用');
      }
      late Map<String, dynamic> v;
      try {
        v = classroomMap(response.data);
      } on FormatException {
        if (write) throw const ClassroomWriteUncertain();
        rethrow;
      }
      if (write && v['code'] == null) throw const ClassroomWriteUncertain();
      if (v['code'] != null && v['code'] != 0) {
        throw FormatException(
          classroomText(v['message']).isEmpty
              ? '学校未通过本次操作'
              : classroomText(v['message']),
        );
      }
      return v.containsKey('code') ? v['data'] : v;
    } on DioException {
      if (write) throw const ClassroomWriteUncertain();
      rethrow;
    } finally {
      if (write) _writing = false;
    }
  }

  Future<ClassroomHome> home() async {
    final campus = classroomMap(
      await _api(
        '/basic/campus',
        query: {
          'page': 1,
          'per_page': -1,
          'fields': 'id,name',
          'filters': r'{"active":{"$eq":1}}',
          'orderby': '[["created_at","desc"]]',
        },
      ),
    );
    final buildings = classroomMap(
      await _api(
        '/basic/buildings',
        query: {
          'page': 1,
          'per_page': -1,
          'filters': r'{"active":{"$eq":1}}',
          'orderby': '[["created_at","desc"]]',
        },
      ),
    );
    final now = DateTime.now();
    final agendas = classroomRows(
      await _api(
        '/agendasList',
        query: {
          'start_date': classroomDate(now),
          'end_date': classroomDate(now.add(const Duration(days: 7))),
        },
      ),
    );
    return ClassroomHome(
      user: user!,
      campuses: classroomRows(
        campus['data'],
      ).map(ClassroomPlace.campus).toList(),
      buildings: classroomRows(
        buildings['data'],
      ).map(ClassroomPlace.building).toList(),
      agendas: agendas.map(ClassroomAgenda.fromJson).toList(),
    );
  }

  Future<List<ClassroomInfo>> rooms({String? campus}) async {
    final v = classroomMap(
      await _api(
        '/customization/roomIntroduction',
        query: {'limit': 10000, 'campus_ids': ?campus},
      ),
    );
    return {
      for (final row in classroomRows(v['data']))
        classroomText(classroomMap(row['room'])['id']):
            ClassroomInfo.fromIntroduction(row),
    }.values.toList();
  }

  Future<ClassroomInfo> room(String id) async => ClassroomInfo.fromIntroduction(
    classroomMap(
      await _api(
        '/customization/roomIntroductionDetail',
        query: {'room_id': id},
      ),
    ),
  );
  Future<List<SeatRoom>> seatRooms({
    String? campus,
    String? building,
    int page = 1,
    String keyword = '',
  }) async => classroomRows(
    await _api(
      '/seatReservation/rooms/cards',
      query: {
        'page': page,
        'per_page': 20,
        'keyword': keyword,
        'campus_id': ?campus,
        'building_id': ?building,
      },
    ),
  ).map(SeatRoom.fromJson).toList();
  Future<SeatRules> seatRules(String room) async => SeatRules.fromJson(
    classroomMap(await _api('/seatReservation/booking-configs/$room')),
  );
  Future<List<ClassroomDateStatus>> seatDates(String room, int days) async =>
      classroomRows(
        await _api(
          '/seatReservation/rooms/$room/date-status',
          query: {
            'start_date': classroomDate(DateTime.now()),
            'end_date': classroomDate(DateTime.now().add(Duration(days: days))),
          },
        ),
      ).map(ClassroomDateStatus.fromJson).toList();
  Future<List<SeatTimeRange>> seatTimes(String room, String date) async {
    final v = classroomMap(
      await _api(
        '/seatReservation/rooms/$room/time-range-status',
        query: {'date': date},
      ),
    );
    return classroomRows(
      v['open_time_ranges'],
    ).map(SeatTimeRange.fromJson).toList();
  }

  Future<List<ClassroomSeat>> seats(
    String room,
    String date,
    String start,
    String end,
  ) async => classroomRows(
    await _api(
      '/seatReservation/rooms/$room/seat-status',
      body: {
        'date': date,
        'time_ranges': [
          {'start_time': start, 'end_time': end},
        ],
      },
    ),
  ).map(ClassroomSeat.fromJson).toList();
  Future<void> bookSeat(
    String room,
    int seat,
    String date,
    String start,
    String end,
  ) async {
    final result = await _api(
      '/seatReservation/booking-orders',
      body: {
        'room_id': room,
        'seat_id': seat,
        'booking_date': date,
        'book_type': 1,
        'book_time_list': [
          {'start_time': start, 'end_time': end},
        ],
      },
      write: true,
    );
    try {
      if (classroomInt(classroomMap(result)['order_id']) <= 0) {
        throw const ClassroomWriteUncertain();
      }
    } on FormatException {
      throw const ClassroomWriteUncertain();
    }
  }

  Future<ClassroomPage<ClassroomBooking>> bookings(int page) async =>
      ClassroomPage.parse(
        await _api(
          '/seatReservation/booking-orders',
          query: {'page': page, 'per_page': 20, 'my_record': 1},
        ),
        ClassroomBooking.fromJson,
      );
  Future<void> cancelBooking(int id) async {
    await _api(
      '/seatReservation/booking-orders/$id/cancel',
      body: {'cancel_reason': '用户取消'},
      write: true,
    );
  }

  Future<ClassroomPage<ClassroomBooking>> seminarBookings(int page) async =>
      ClassroomPage.parse(
        await _api(
          '/room-book-records',
          query: {
            'page': page,
            'per_page': 20,
            'direction': 'refresh',
            'lastTime': 0,
            'extends': 1,
            'orderby': '[["start_date","desc"],["start_time","desc"]]',
          },
        ),
        ClassroomBooking.fromSeminar,
      );
  Future<void> cancelSeminar(int id) async {
    await _api(
      '/book-records/$id',
      method: 'DELETE',
      body: {'reason': '用户取消'},
      write: true,
    );
  }

  Future<List<ClassroomPlace>> floorBuildings() async {
    final rows = classroomRows(await _api('/modelingCampusBuilding'));
    return [
      for (final campus in rows)
        for (final b in classroomRows(campus['building_list']))
          ClassroomPlace(
            classroomText(b['building_id']),
            classroomText(b['building_name']),
            campusId: classroomText(campus['campus_id']),
          ),
    ];
  }

  Future<List<ClassroomInfo>> selfStudy(String building, String date) async {
    final v = classroomMap(
      await _api(
        '/selfStudyRoom/guide',
        query: {'building_id': building, 'date': date, 'with_midday_borrow': 1},
      ),
    );
    return classroomRows(v['room_list']).map(ClassroomInfo.fromStudy).toList();
  }

  Future<List<ClassroomInfo>> floors(String building) async {
    final v = classroomMap(
      await _api(
        '/schedules/building-schedules-pad-with-self-study',
        query: {'building_id': building},
      ),
    );
    final rows = <ClassroomInfo>[];
    for (final f in classroomRows(v['floor_info'])) {
      rows.addAll(classroomRows(f['rooms']).map(ClassroomInfo.fromFloor));
    }
    return {for (final row in rows) row.id: row}.values.toList();
  }

  Future<ClassroomPage<ClassroomLecture>> lectures(int page) async =>
      ClassroomPage.parse(
        await _api(
          '/customization/lecture',
          query: {
            'page': page,
            'per_page': 20,
            'orderby': '[["lecture_date","desc"]]',
          },
        ),
        ClassroomLecture.fromJson,
      );
  Future<ClassroomPage<ClassroomLostItem>> lostItems(int page) async =>
      ClassroomPage.parse(
        await _api(
          '/lostfound/lost',
          query: {'status': 0, 'scene': 0, 'page': page, 'limit': 20},
        ),
        ClassroomLostItem.fromJson,
      );
  Future<List<ClassroomFeedback>> feedback() async => classroomRows(
    await _api('/xmu/feedback/my'),
  ).map(ClassroomFeedback.fromJson).toList();
  Future<ClassroomPage<ClassroomSeminar>> seminars(
    int page, {
    String? campus,
    String? building,
  }) async => ClassroomPage.parse(
    await _api(
      '/function-rooms',
      query: {
        'page': page,
        'per_page': 20,
        'campus_id': ?campus,
        'building_id': ?building,
      },
    ),
    ClassroomSeminar.fromJson,
  );
  Future<String> seminarRule(String room) async =>
      classroomPlain(await _api('/v2/book_rule', query: {'room_id': room}));
  Future<int> seminarAvailability(
    String room,
    String date,
    String start,
    String end,
  ) async {
    final v = classroomMap(
      await _api(
        '/function-rooms/$room',
        query: {
          'start_date': date,
          'start_time': '$start:00',
          'end_time': '$end:00',
        },
      ),
    );
    return classroomInt(v['leave_num']);
  }

  Future<void> bookSeminar(
    String room,
    String date,
    String start,
    String end,
    String purpose,
    int people,
    bool allowMany,
  ) async {
    await _api(
      '/customization/addBook',
      body: {
        'room_id': room,
        'start_date': date,
        'start_time': '$start:00',
        'end_time': '$end:00',
        'purpose': purpose,
        'people_num': people,
        'allow_many': allowMany ? 1 : 0,
      },
      write: true,
    );
  }

  Future<List<ClassroomFeedbackChoice>> feedbackCategories() async =>
      classroomRows(
        await _api('/customization/feedback-category-all'),
      ).map(ClassroomFeedbackChoice.fromJson).toList();
  Future<List<ClassroomFeedbackChoice>> feedbackTypes() async => classroomRows(
    classroomMap(await _api('/xmu/feedbacktype'))['data'],
  ).map(ClassroomFeedbackChoice.fromJson).toList();
  Future<void> sendFeedback({
    required ClassroomInfo room,
    required String campus,
    required String building,
    required String category,
    required String type,
    required String phone,
    required String content,
  }) async {
    await _api(
      '/xmu/feedback',
      body: {
        'campus_id': campus,
        'building_id': building,
        'room_id': room.id,
        'category_id': category,
        'type': type,
        'phone': phone,
        'content': content,
      },
      write: true,
    );
  }

  void close() => dio.close(force: true);
}
