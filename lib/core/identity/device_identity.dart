import 'package:uuid/uuid.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';

/// Install-stable device id (KB-01: never regenerate per request).
class DeviceIdentity {
  DeviceIdentity(this._store);

  final SecureStore _store;
  String? _cached;

  Future<String> getId() async {
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
