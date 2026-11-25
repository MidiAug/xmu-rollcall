import 'dart:convert';

Map<String, dynamic> classroomMap(Object? v) {
  if (v is String) v = jsonDecode(v);
  if (v is! Map<String, dynamic>) throw const FormatException('教室数据格式异常');
  return v;
}

List<Map<String, dynamic>> classroomRows(Object? v) {
  if (v is! List) throw const FormatException('教室列表格式异常');
  return v.map(classroomMap).toList();
}

String classroomText(Object? v) => v == null ? '' : '$v'.trim();
String classroomPlain(Object? v) => classroomText(v)
    .replaceAll(RegExp(r'<[^>]*>'), '')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', '&');
int classroomInt(Object? v) {
  final value = int.tryParse(classroomText(v));
  if (value == null) throw const FormatException('教室数值格式异常');
  return value;
}

String classroomDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class ClassroomUser {
  const ClassroomUser(this.id, this.code, this.campusIds);
  final String id, code;
  final List<String> campusIds;
  factory ClassroomUser.fromJson(Map<String, dynamic> v) {
    final id = classroomText(v['id']), code = classroomText(v['code']);
    if (id.isEmpty || code.isEmpty) throw const FormatException('教室账号信息缺失');
    return ClassroomUser(
      id,
      code,
      (v['campus_ids'] as List? ?? []).map(classroomText).toList(),
    );
  }
  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'campus_ids': campusIds,
  };
}

class ClassroomPlace {
  const ClassroomPlace(this.id, this.name, {this.campusId});
  final String id, name;
  final String? campusId;
  factory ClassroomPlace.campus(Map<String, dynamic> v) =>
      ClassroomPlace(classroomText(v['id']), classroomText(v['name']));
  factory ClassroomPlace.building(Map<String, dynamic> v) => ClassroomPlace(
    classroomText(v['id']),
    classroomText(v['name']),
    campusId: classroomText(v['campus_id']),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'campus_id': campusId,
  };
}

class ClassroomAgenda {
  const ClassroomAgenda(this.title, this.start, this.end);
  final String title, start, end;
  factory ClassroomAgenda.fromJson(Map<String, dynamic> v) => ClassroomAgenda(
    classroomText(v['title'] ?? v['name']),
    classroomText(v['start_time']),
    classroomText(v['end_time']),
  );
  Map<String, dynamic> toJson() => {
    'title': title,
    'start_time': start,
    'end_time': end,
  };
}

class ClassroomHome {
  const ClassroomHome({
    required this.user,
    required this.campuses,
    required this.buildings,
    required this.agendas,
  });
  final ClassroomUser user;
  final List<ClassroomPlace> campuses, buildings;
  final List<ClassroomAgenda> agendas;
  Map<String, dynamic> toJson() => {
    'user': user.toJson(),
    'campuses': campuses.map((v) => v.toJson()).toList(),
    'buildings': buildings.map((v) => v.toJson()).toList(),
    'agendas': agendas.map((v) => v.toJson()).toList(),
  };
  factory ClassroomHome.fromJson(Map<String, dynamic> v) => ClassroomHome(
    user: ClassroomUser.fromJson(classroomMap(v['user'])),
    campuses: classroomRows(v['campuses']).map(ClassroomPlace.campus).toList(),
    buildings: classroomRows(
      v['buildings'],
    ).map(ClassroomPlace.building).toList(),
    agendas: classroomRows(v['agendas']).map(ClassroomAgenda.fromJson).toList(),
  );
}

class ClassroomPage<T> {
  const ClassroomPage(this.items, this.nextPage);
  final List<T> items;
  final int? nextPage;
  static ClassroomPage<T> parse<T>(
    Object? raw,
    T Function(Map<String, dynamic>) decode,
  ) {
    final v = classroomMap(raw);
    final current = classroomInt(v['current_page']),
        last = classroomInt(v['last_page']);
    return ClassroomPage(
      classroomRows(v['data']).map(decode).toList(),
      current < last ? current + 1 : null,
    );
  }
}

class ClassroomInfo {
  const ClassroomInfo({
    required this.id,
    required this.name,
    this.building = '',
    this.buildingId = '',
    this.category = '',
    this.floor = '',
    this.capacity = '',
    this.introduction = '',
    this.images = const [],
    this.periods = const [],
    this.occupied = false,
  });
  final String id,
      name,
      building,
      buildingId,
      category,
      floor,
      capacity,
      introduction;
  final List<String> images;
  final List<StudyPeriod> periods;
  final bool occupied;
  factory ClassroomInfo.fromIntroduction(Map<String, dynamic> v) {
    final room = classroomMap(v['room']);
    return ClassroomInfo(
      id: classroomText(room['id']),
      name: classroomText(room['room_name'] ?? room['name']),
      building: classroomText(room['building_name']),
      buildingId: classroomText(room['building_id']),
      category: classroomText(room['category_name']),
      floor: classroomText(room['floor']),
      capacity: classroomText(room['seat_number']),
      introduction: classroomPlain(v['introduction']),
      images: (v['image_files'] as List? ?? []).map(classroomText).toList(),
    );
  }
  factory ClassroomInfo.fromStudy(Map<String, dynamic> v) {
    final room = classroomMap(v['room']);
    return ClassroomInfo(
      id: classroomText(room['id']),
      name: classroomText(room['name']),
      floor: classroomText(room['floor']),
      category: classroomText(room['category_name']),
      capacity: classroomText(room['seat_number']),
      periods: classroomRows(v['list']).map(StudyPeriod.fromJson).toList(),
    );
  }
  factory ClassroomInfo.fromFloor(Map<String, dynamic> v) {
    final schedule = classroomMap(v['schedule_info']);
    return ClassroomInfo(
      id: classroomText(v['id']),
      name: classroomText(v['name']),
      floor: classroomText(v['floor']),
      category: classroomText(v['category_name']),
      capacity: classroomText(v['seat_count']),
      occupied: classroomInt(schedule['has_room_occupation']) != 0,
      introduction: classroomText(schedule['subject']),
    );
  }
}

class StudyPeriod {
  const StudyPeriod(
    this.index,
    this.start,
    this.end,
    this.status,
    this.expired,
  );
  final int index, status;
  final String start, end;
  final bool expired;
  factory StudyPeriod.fromJson(Map<String, dynamic> v) => StudyPeriod(
    classroomInt(v['index']),
    classroomText(v['start_time']),
    classroomText(v['end_time']),
    classroomInt(v['status']),
    v['expire'] == true,
  );
}

class SeatRoom {
  const SeatRoom(this.id, this.name, this.occupied, this.total);
  final String id, name;
  final int occupied, total;
  factory SeatRoom.fromJson(Map<String, dynamic> v) => SeatRoom(
    classroomText(v['room_id']),
    classroomText(v['room_name']),
    classroomInt(v['occupied_seats']),
    classroomInt(v['total_seats']),
  );
}

class ClassroomSeat {
  const ClassroomSeat(this.id, this.name, this.status);
  final int id, status;
  final String name;
  factory ClassroomSeat.fromJson(Map<String, dynamic> v) => ClassroomSeat(
    classroomInt(v['id']),
    classroomText(v['seat_name']).isEmpty
        ? classroomText(v['seat_code'])
        : classroomText(v['seat_name']),
    classroomInt(v['seat_status']),
  );
}

class ClassroomDateStatus {
  const ClassroomDateStatus(this.date, this.status);
  final String date;
  final int status;
  factory ClassroomDateStatus.fromJson(Map<String, dynamic> v) =>
      ClassroomDateStatus(classroomText(v['date']), classroomInt(v['status']));
}

class SeatTimeRange {
  const SeatTimeRange(this.start, this.end);
  final String start, end;
  factory SeatTimeRange.fromJson(Map<String, dynamic> v) => SeatTimeRange(
    classroomText(v['start_time']),
    classroomText(v['end_time']),
  );
}

class SeatRules {
  const SeatRules({
    required this.open,
    required this.days,
    required this.minimum,
    required this.maximum,
    required this.notice,
    required this.promise,
  });
  final bool open;
  final int days, minimum, maximum;
  final String notice, promise;
  factory SeatRules.fromJson(Map<String, dynamic> v) => SeatRules(
    open: v['room_open'] == 1,
    days: classroomInt(v['max_advance_days']),
    minimum: classroomInt(v['min_duration_minutes']),
    maximum: classroomInt(v['max_duration_minutes']),
    notice: classroomText(v['notice_text']),
    promise: classroomText(v['promise_text']),
  );
}

class ClassroomBooking {
  const ClassroomBooking(
    this.id,
    this.room,
    this.seat,
    this.status,
    this.periods,
    this.canCancel, {
    this.seminar = false,
  });
  final int id;
  final String room, seat, status;
  final List<String> periods;
  final bool canCancel, seminar;
  factory ClassroomBooking.fromJson(Map<String, dynamic> v) => ClassroomBooking(
    classroomInt(v['id']),
    classroomText(v['room_name']),
    classroomText(v['seat_code']),
    classroomText(v['order_status_text']),
    classroomRows(v['items'])
        .map(
          (v) =>
              '${classroomText(v['booking_date'] ?? v['date'])} ${classroomText(v['start_time'])}—${classroomText(v['end_time'])}',
        )
        .toList(),
    v['can_cancel'] == true,
  );
  factory ClassroomBooking.fromSeminar(Map<String, dynamic> v) {
    final room = classroomMap(v['room']);
    final status = classroomInt(v['status']);
    final showCancel = v['show_cancel_btn'];
    return ClassroomBooking(
      classroomInt(v['id']),
      '${classroomText(room['building_name'])} ${classroomText(room['name'])}'
          .trim(),
      '研讨室',
      classroomText(
        v['display_status_text'] ??
            v['checkout_status_text'] ??
            v['status_text'],
      ),
      [
        '${classroomText(v['start_date'])} ${classroomText(v['start_time'])}—${classroomText(v['end_time'])}',
      ],
      const [0, 5, 6].contains(status) &&
          !const [false, 0, '0', 'false'].contains(showCancel),
      seminar: true,
    );
  }
}

class ClassroomLecture {
  const ClassroomLecture(
    this.id,
    this.title,
    this.speaker,
    this.date,
    this.time,
    this.position,
    this.content,
  );
  final String id, title, speaker, date, time, position, content;
  factory ClassroomLecture.fromJson(Map<String, dynamic> v) => ClassroomLecture(
    classroomText(v['id']),
    classroomText(v['title']),
    classroomText(v['speaker']),
    classroomText(v['lecture_date']),
    classroomText(v['start_time']),
    classroomText(v['position']),
    classroomPlain(v['content']),
  );
}

class ClassroomLostItem {
  const ClassroomLostItem(
    this.id,
    this.title,
    this.content,
    this.position,
    this.time,
  );
  final String id, title, content, position, time;
  factory ClassroomLostItem.fromJson(Map<String, dynamic> v) =>
      ClassroomLostItem(
        classroomText(v['id']),
        classroomText(v['name']),
        classroomPlain(v['content']),
        classroomText(v['position']),
        classroomText(v['find_time']),
      );
}

class ClassroomFeedback {
  const ClassroomFeedback(this.id, this.content, this.status, this.time);
  final String id, content, status, time;
  factory ClassroomFeedback.fromJson(Map<String, dynamic> v) =>
      ClassroomFeedback(
        classroomText(v['id']),
        classroomPlain(v['content']),
        classroomText(v['status_text'] ?? v['status']),
        classroomText(v['created_at']),
      );
}

class ClassroomSeminar {
  const ClassroomSeminar({
    required this.id,
    required this.name,
    required this.location,
    required this.capacity,
    required this.dates,
    required this.type,
    required this.mode,
  });
  final String id, name, location, mode;
  final int capacity, type;
  final List<String> dates;
  factory ClassroomSeminar.fromJson(Map<String, dynamic> v) => ClassroomSeminar(
    id: classroomText(v['id']),
    name: classroomText(v['name']),
    location: classroomText(v['location']),
    capacity: classroomInt(v['seat_number']),
    dates: (v['bookable_dates'] as List? ?? []).map(classroomText).toList(),
    type: classroomInt(v['book_type']),
    mode: classroomText(v['booking_mode']),
  );
}

class ClassroomFeedbackChoice {
  const ClassroomFeedbackChoice(this.id, this.name);
  final String id, name;
  factory ClassroomFeedbackChoice.fromJson(Map<String, dynamic> v) =>
      ClassroomFeedbackChoice(
        classroomText(v['id']),
        classroomText(v['category_name'] ?? v['name']),
      );
}
