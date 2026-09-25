import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/platform/close_prefs.dart';

final closePrefsProvider =
    StateNotifierProvider<ClosePrefsController, ClosePrefs>((ref) {
  return ClosePrefsController();
});

class ClosePrefsController extends StateNotifier<ClosePrefs> {
  ClosePrefsController() : super(const ClosePrefs()) {
    _load();
  }

  static const _kToTray = 'close_to_tray';
  static const _kPrefSet = 'close_pref_set';
  static const _kRememberUsed = 'close_remember_default_used';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = ClosePrefs(
      closeToTray: prefs.getBool(_kToTray) ?? true,
      closePrefSet: prefs.getBool(_kPrefSet) ?? false,
      closeRememberDefaultUsed: prefs.getBool(_kRememberUsed) ?? false,
    );
  }

  Future<void> setMode(CloseMode mode) async {
    final next = ClosePrefs.fromMode(
      mode,
      rememberUsed: state.closeRememberDefaultUsed,
    );
    state = next;
    await _persist(next);
  }

  Future<void> applyAskChoice({
    required bool toTray,
    required bool remember,
  }) async {
    final next = state.afterAskChoice(toTray: toTray, remember: remember);
    state = next;
    await _persist(next);
  }

  /// Mark remember-default as used without changing tray/quit preference
  /// (e.g. ask dialog action with remember unchecked while still ask mode).
  Future<void> markRememberDefaultUsed() async {
    if (state.closeRememberDefaultUsed) return;
    final next = state.copyWith(closeRememberDefaultUsed: true);
    state = next;
    await _persist(next);
  }

  Future<void> _persist(ClosePrefs p) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kToTray, p.closeToTray);
    await prefs.setBool(_kPrefSet, p.closePrefSet);
    await prefs.setBool(_kRememberUsed, p.closeRememberDefaultUsed);
  }
}
