import 'dart:convert';

import 'package:xmu_rollcall/core/session/assist_identity.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';

class AssistIdentityStore {
  AssistIdentityStore(this._store);

  final SecureStore _store;
  static final _writes = Expando<Future<void>>();

  Future<void> _mutate(Future<void> Function() change) {
    final previous = _writes[_store] ?? Future<void>.value();
    final result = previous.then((_) => change());
    final tail = result.catchError((Object _) {});
    _writes[_store] = tail;
    return result.whenComplete(() {
      if (identical(_writes[_store], tail)) _writes[_store] = null;
    });
  }

  static const rosterKey = 'assist_identities_json';

  Future<List<AssistIdentity>> list() async {
    final raw = await _store.read(rosterKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map(
            (e) => AssistIdentity.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .where((e) => e.userId > 0)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> upsert(AssistIdentity identity) => _mutate(() async {
    final items = await list();
    final next = [...items.where((e) => e.userId != identity.userId), identity]
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
    await _store.write(
      rosterKey,
      jsonEncode(next.map((e) => e.toJson()).toList()),
    );
  });

  Future<void> remove(int userId) => _mutate(() async {
    final next = (await list()).where((e) => e.userId != userId).toList();
    if (next.isEmpty) {
      await _store.delete(rosterKey);
    } else {
      await _store.write(
        rosterKey,
        jsonEncode(next.map((e) => e.toJson()).toList()),
      );
    }
  });
}
