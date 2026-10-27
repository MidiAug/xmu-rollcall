import 'package:uuid/uuid.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';

/// Student-stable identity. Unknown accounts retain their install ID until
/// a verified student number becomes available; never regenerate per request.
class DeviceIdentity {
  DeviceIdentity(this._store);

  final SecureStore _store;
  String? _cached;
  Future<String>? _loading;

  static String? forStudentNumber(String? value) {
    final student = value?.trim();
    if (student == null || !RegExp(r'^\d{5,24}$').hasMatch(student)) {
      return null;
    }
    return const Uuid().v5(
      Namespace.url.value,
      'https://xmu.edu.cn/xmu-rollcall/device/student/$student',
    );
  }

  Future<String> bindStudentNumber(String? studentNo) async {
    final id = forStudentNumber(studentNo);
    if (id == null) return getId();
    if (_loading != null) await _loading;
    await _store.write(SecureStore.keyDeviceId, id);
    _cached = id;
    return id;
  }

  Future<String> getId() {
    if (_cached != null) return Future.value(_cached!);
    return _loading ??= _loadId().whenComplete(() => _loading = null);
  }

  Future<String> _loadId() async {
    if (_cached != null) return _cached!;
    final existing = await _store.read(SecureStore.keyDeviceId);
    if (existing != null && existing.isNotEmpty) {
      _cached = existing;
      return existing;
    }
    final id = const Uuid().v4();
    await _store.write(SecureStore.keyDeviceId, id);
    _cached = id;
    return id;
  }
}
