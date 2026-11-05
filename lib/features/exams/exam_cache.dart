import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'exam_models.dart';

// Local snapshot reads never mount page state or prepare a remote session.
String examCacheKey(int owner, int uid, String term) =>
    'exams_v1_${owner}_${uid}_$term';
ExamSnapshot? readExamCache(
  SharedPreferences prefs,
  int owner,
  int uid,
  String term,
) {
  try {
    final raw = prefs.getString(examCacheKey(owner, uid, term));
    if (raw == null) return null;
    final snapshot = ExamSnapshot.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
    return snapshot.term == term ? snapshot : null;
  } catch (_) {
    return null;
  }
}
