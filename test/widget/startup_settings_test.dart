import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/app/app_switch.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/assist/assist_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';
import 'package:xmu_rollcall/features/monitor/monitor_controller.dart';
import 'package:xmu_rollcall/features/settings/startup_settings.dart';
import 'package:xmu_rollcall/platform/windows_startup.dart';

class _Repository extends Fake implements AuthRepository {}

class _Auth extends AuthController {
  _Auth() : super(_Repository()) {
    state = const AuthState(
      status: AuthStatus.signedIn,
      profile: UserProfile(id: 1, name: '测试'),
    );
  }
}

class _Startup extends WindowsStartup {
  _Startup() : super(supported: true);
  bool enabled = false;
  int writes = 0;
  @override
  Future<bool> isEnabled() async => enabled;
  @override
  Future<void> setEnabled(bool value) async {
    writes++;
    enabled = value;
  }
}

void main() {
  testWidgets(
    'launch preferences persist separately and opening settings never registers startup',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final startup = _Startup();
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith((ref) => _Auth()),
          assistControllerProvider.overrideWith(
            (ref) => AssistController(
              ref,
              initial: const AssistUiState(ready: true),
              bootstrap: false,
            ),
          ),
          windowsStartupProvider.overrideWithValue(startup),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light().copyWith(platform: TargetPlatform.windows),
            home: const Scaffold(
              body: SingleChildScrollView(child: StartupSettings()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final resume = find.byKey(const ValueKey('monitor-resume-watch'));
      final boot = find.byKey(const ValueKey('monitor-startup'));
      expect(tester.getTopLeft(boot).dy, lessThan(tester.getTopLeft(resume).dy));
      expect(startup.writes, 0);
      expect(tester.widget<AppSwitch>(resume).onChanged, isNull);
      final ctrl = container.read(monitorControllerProvider.notifier);
      ctrl.setCourseWatch(true);
      await tester.pumpAndSettle();
      await tester.tap(resume);
      await tester.pumpAndSettle();
      expect(
        container.read(monitorControllerProvider).config.resumeWatch,
        isTrue,
      );
      expect(container.read(monitorControllerProvider).running, isFalse);
      expect(
        (await SharedPreferences.getInstance()).getBool(
          'monitor_account_1_1_resume_watch',
        ),
        isTrue,
      );
      expect(startup.writes, 0);
      await tester.tap(boot);
      await tester.pumpAndSettle();
      expect(startup.enabled, isTrue);
      expect(startup.writes, 1);
      expect(
        container.read(monitorControllerProvider).config.resumeWatch,
        isTrue,
      );
      await tester.tap(boot);
      await tester.tap(resume);
      await tester.pumpAndSettle();
      expect(startup.enabled, isFalse);
      expect(
        container.read(monitorControllerProvider).config.resumeWatch,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
