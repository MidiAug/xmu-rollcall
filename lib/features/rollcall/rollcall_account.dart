import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/assist/assist_controller.dart';

/// Null selects the directly logged-in session; an ID selects an imported one.
/// This is a credential distinction, not a difference in sign-in capabilities.
final selectedRollcallAccountProvider =
    StateNotifierProvider<SelectedRollcallAccountController, int?>((ref) {
      final ownerId = ref.watch(
        authControllerProvider.select((a) => a.profile?.id),
      );
      return SelectedRollcallAccountController(ref, ownerId);
    });

class SelectedRollcallAccountController extends StateController<int?> {
  SelectedRollcallAccountController(this._ref, this.ownerId) : super(null) {
    _ref.listen(assistControllerProvider, (_, next) {
      if (!next.ready) return;
      if (!_restored) {
        _restore();
      } else if (state != null &&
          !next.identities.any((a) => a.userId == state)) {
        state = null;
      }
    });
    unawaited(_load());
  }

  final Ref _ref;
  final int? ownerId;
  bool restoring = false;
  bool _loaded = false;
  bool _restored = false;
  int? _saved;
  Future<void> _writes = Future.value();
  String get _key => 'rollcall_selected_account_$ownerId';

  Future<void> _load() async {
    if (ownerId == null || ownerId == 0) return;
    SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {
      return;
    }
    if (!mounted || _restored) return;
    _saved = prefs.getInt(_key);
    _loaded = true;
    _restore();
  }

  void _restore() {
    if (!mounted || !_loaded || _restored) return;
    final roster = _ref.read(assistControllerProvider);
    if (!roster.ready) return;
    _restored = true;
    final id = roster.identities.any((a) => a.userId == _saved) ? _saved : null;
    restoring = true;
    super.state = id;
    restoring = false;
  }

  @override
  set state(int? value) {
    _restored = true;
    super.state = value;
    if (ownerId == null || ownerId == 0) return;
    _writes = _writes
        .then((_) async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt(_key, value ?? 0);
        })
        .catchError((Object _) {});
  }
}

final rollcallAccountNameProvider = Provider<String>((ref) {
  final id = ref.watch(selectedRollcallAccountProvider);
  if (id == null) {
    return ref.watch(authControllerProvider).profile?.name ?? '未登录';
  }
  return ref
          .watch(assistControllerProvider)
          .identities
          .where((a) => a.userId == id)
          .firstOrNull
          ?.displayName ??
      '账号不可用';
});
