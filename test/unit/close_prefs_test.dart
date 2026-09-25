import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/platform/close_prefs.dart';

void main() {
  group('ClosePrefs', () {
    test('default mode is ask', () {
      const p = ClosePrefs();
      expect(p.mode, CloseMode.ask);
      expect(p.rememberCheckboxDefault, isTrue);
    });

    test('fromMode encoding matches sports', () {
      final ask = ClosePrefs.fromMode(CloseMode.ask, rememberUsed: false);
      expect(ask.closePrefSet, isFalse);
      expect(ask.closeToTray, isTrue);

      final tray = ClosePrefs.fromMode(CloseMode.tray, rememberUsed: true);
      expect(tray.closePrefSet, isTrue);
      expect(tray.closeToTray, isTrue);
      expect(tray.mode, CloseMode.tray);

      final quit = ClosePrefs.fromMode(CloseMode.quit, rememberUsed: true);
      expect(quit.closePrefSet, isTrue);
      expect(quit.closeToTray, isFalse);
      expect(quit.mode, CloseMode.quit);
    });

    test('afterAskChoice always marks remember default used', () {
      const p = ClosePrefs();
      final remembered = p.afterAskChoice(toTray: true, remember: true);
      expect(remembered.closePrefSet, isTrue);
      expect(remembered.closeToTray, isTrue);
      expect(remembered.closeRememberDefaultUsed, isTrue);
      expect(remembered.rememberCheckboxDefault, isFalse);

      final forgotten = p.afterAskChoice(toTray: false, remember: false);
      expect(forgotten.closePrefSet, isFalse);
      expect(forgotten.closeToTray, isFalse);
      expect(forgotten.closeRememberDefaultUsed, isTrue);
      expect(forgotten.mode, CloseMode.ask);
    });

    test('remember checkbox default only first lifetime', () {
      const first = ClosePrefs(closeRememberDefaultUsed: false);
      expect(first.rememberCheckboxDefault, isTrue);
      const later = ClosePrefs(closeRememberDefaultUsed: true);
      expect(later.rememberCheckboxDefault, isFalse);
    });
  });
}
