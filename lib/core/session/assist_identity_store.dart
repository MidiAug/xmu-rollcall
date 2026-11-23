import 'dart:convert';

import 'package:xmu_rollcall/core/logging/app_log.dart';
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
  static const corruptBackupKey = '${rosterKey}_corrupt_backup';

  Future<({List<AssistIdentity> items, String? raw, bool corrupt})>
  _readRoster() async {
    final raw = await _store.read(rosterKey);
    if (raw == null || raw.isEmpty) {
      return (items: const <AssistIdentity>[], raw: raw, corrupt: false);
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final items = list
          .map(
            (e) => AssistIdentity.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .where((e) => e.userId > 0)
          .toList();
      return (items: items, raw: raw, corrupt: false);
    } catch (error) {
      AppLog.event(
        'assist.roster.corrupt',
        level: 'W',
        fields: {'errorType': error.runtimeType.toString()},
      );
      return (items: const <AssistIdentity>[], raw: raw, corrupt: true);
    }
  }

  Future<List<AssistIdentity>> _readForMutation() async {
    final result = await _readRoster();
    if (result.corrupt && result.raw != null) {
      await _store.write(corruptBackupKey, result.raw!);
      throw const FormatException('协助身份列表已损坏，已备份原数据并阻止覆盖');
    }
    return result.items;
  }

  Future<List<AssistIdentity>> list() async => (await _readRoster()).items;

  Future<void> upsert(AssistIdentity identity) => _mutate(() async {
    final items = await _readForMutation();
    final next = [...items.where((e) => e.userId != identity.userId), identity]
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
    await _store.write(
      rosterKey,
      jsonEncode(next.map((e) => e.toJson()).toList()),
    );
  });

  Future<void> remove(int userId) => _mutate(() async {
    final next = (await _readForMutation())
        .where((e) => e.userId != userId)
        .toList();
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
