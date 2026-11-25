import 'package:xmu_rollcall/core/cache/cache_revisions.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/features/academic/academic_access.dart';
import 'package:xmu_rollcall/features/browser/browser_session.dart';
import 'lecture_requirement.dart';
export 'lecture_requirement.dart';

String lectureRequirementKey(BrowserIdentity v) =>
    'lecture_requirement_v1_${v.ownerId}_${v.userId}';
final lectureRequirementReaderProvider =
    Provider<LectureRequirementReader Function()>((ref) {
      final create = ref.watch(academicSessionFactoryProvider);
      return () => LectureRequirementReader(create());
    });
final lectureRequirementProvider =
    AsyncNotifierProvider.autoDispose<
      LectureRequirementNotifier,
      LectureRequirement?
    >(LectureRequirementNotifier.new);

class LectureRequirementNotifier
    extends AutoDisposeAsyncNotifier<LectureRequirement?> {
  int _revision = 0;
  late BrowserIdentity _identity;
  Future<LectureRequirement?>? _flight;
  DateTime? _attempt;
  bool _current(int r) =>
      r == _revision && ref.read(browserIdentityProvider) == _identity;
  @override
  Future<LectureRequirement?> build() async {
    final r = ++_revision;
    _flight = null;
    _attempt = null;
    _identity = ref.watch(browserIdentityProvider);
    ref.onDispose(() => _revision++);
    if (_identity.userId == null) return null;
    final p = await SharedPreferences.getInstance();
    if (!_current(r)) throw StateError('账号已切换');
    final raw = p.getString(lectureRequirementKey(_identity));
    if (raw != null) {
      try {
        final cached = LectureRequirement.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map),
        );
        if (DateTime.now().difference(cached.fetchedAt) >=
            const Duration(days: 7)) {
          unawaited(
            Future<void>(() async {
              if (_current(r)) await refresh();
            }),
          );
        }
        return cached;
      } on FormatException {
        /* Read damaged cache again from the owning source. */
      } on TypeError {
        /* Old cache shape. */
      }
    }
    return _fetch(r);
  }

  Future<LectureRequirement?> _fetch(int r) async {
    _attempt = DateTime.now();
    final identity = _identity;
    final access = await ref.read(academicIdentityResolverProvider)(
      identity.userId!,
    );
    if (!_current(r)) throw StateError('账号已切换');
    if (access == null) return null;
    final reader = ref.read(lectureRequirementReaderProvider)();
    reader.session.identityGuard = () async =>
        _current(r) && await access.isCurrent();
    final value = await reader.fetch(identity.userId!, access);
    if (!_current(r) || !await access.isCurrent()) throw StateError('账号已切换');
    final p = await SharedPreferences.getInstance();
    if (!_current(r)) throw StateError('账号已切换');
    if (value != null) {
      await p.setString(
        lectureRequirementKey(identity),
        jsonEncode(value.toJson()),
      );
    }
    if (!_current(r)) throw StateError('账号已切换');
    ref.read(lectureCacheRevisionProvider.notifier).state++;
    return value;
  }

  Future<void> refresh() async {
    if (_identity.userId == null ||
        _flight != null ||
        (_attempt != null &&
            DateTime.now().difference(_attempt!) <
                const Duration(seconds: 15))) {
      return;
    }
    final r = _revision;
    try {
      final value = await (_flight = _fetch(r));
      if (_current(r)) state = AsyncData(value);
    } catch (e, st) {
      if (_current(r) && !state.hasValue) state = AsyncError(e, st);
    } finally {
      if (_current(r)) _flight = null;
    }
  }
}
