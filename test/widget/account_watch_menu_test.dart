import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/session/assist_identity.dart';
import 'package:xmu_rollcall/core/session/session_credential.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';
import 'package:xmu_rollcall/features/assist/assist_controller.dart';
import 'package:xmu_rollcall/features/monitor/monitor_controller.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account_menu.dart';
import '../fixtures/preview_fonts.dart';

class _Repo extends Fake implements AuthRepository {}

class _Auth extends AuthController {
  _Auth() : super(_Repo()) {
    state = const AuthState(
      status: AuthStatus.signedIn,
      profile: UserProfile(id: 1, name: '值守同学'),
    );
  }
}

void main() {
  setUpAll(loadDesktopPreviewFonts);
  for (final dark in [false, true]) {
    testWidgets(
      'account menu preserves hidden watch and renders status dark=$dark',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(960, 680);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final container = ProviderContainer(
          overrides: [
            authControllerProvider.overrideWith((ref) => _Auth()),
            assistControllerProvider.overrideWith(
              (ref) => AssistController(
                ref,
                bootstrap: false,
                initial: const AssistUiState(
                  ready: true,
                  identities: [
                    AssistIdentity(
                      userId: 2,
                      displayName: '另一位同学',
                      kind: AssistCredentialKind.session,
                      deviceId: 'test-device',
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: RepaintBoundary(
              key: const ValueKey('watch-menu-capture'),
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: dark ? AppTheme.dark() : AppTheme.light(),
                home: Scaffold(
                  body: Consumer(
                    builder: (context, ref, _) {
                      final states = ref.watch(accountMonitorStatesProvider);
                      final selected = ref.watch(
                        selectedRollcallAccountProvider,
                      );
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Align(
                          alignment: Alignment.bottomLeft,
                          child: SizedBox(
                            width: 156,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                RollcallAccountMenu(
                                  sidebar: true,
                                  width: 156,
                                  value: selected ?? 0,
                                  ownerName: '值守同学',
                                  identities: ref
                                      .watch(assistControllerProvider)
                                      .identities,
                                  watchingAccounts: {
                                    for (final e in states.entries)
                                      if (e.value.running &&
                                          e.value.config.courseWatch)
                                        e.key ?? 0,
                                  },
                                  onChanged: (id) =>
                                      ref
                                          .read(
                                            selectedRollcallAccountProvider
                                                .notifier,
                                          )
                                          .state = id == 0
                                      ? null
                                      : id,
                                ),
                                TextButton(
                                  onPressed: () => ref
                                      .read(monitorControllerProvider.notifier)
                                      .stop(),
                                  child: const Text('暂停当前账号'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final monitor = container.read(monitorControllerProvider.notifier);
        monitor.setCourseWatch(true);
        monitor.debugArmRunning();
        await tester.pumpAndSettle();
        expect(find.byTooltip('值守中'), findsOneWidget);
        expect(find.byType(CircleAvatar), findsOneWidget);
        await tester.tap(find.text('值守同学'));
        await tester.pumpAndSettle();
        expect(find.text('值守中'), findsOneWidget);
        expect(find.byIcon(AppIcons.guard), findsNWidgets(2));
        if (Platform.environment['CAPTURE_WATCH_MENU'] == '1') {
          await tester.runAsync(() async {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const ValueKey('watch-menu-capture')),
            );
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory(
              'build/watch-account-review',
            ).create(recursive: true);
            await File(
              'build/watch-account-review/menu-$dark.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.tap(find.text('另一位同学'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('值守中'), findsNothing);
        expect(container.read(accountMonitorProvider(null)).running, isTrue);
        await tester.tap(find.text('暂停当前账号'));
        await tester.pumpAndSettle();
        expect(container.read(accountMonitorProvider(null)).running, isTrue);
        await tester.tap(find.text('另一位同学'));
        await tester.pumpAndSettle();
        expect(find.text('值守中'), findsOneWidget);
        await tester.tap(find.text('值守同学'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('值守中'), findsOneWidget);
        await tester.tap(find.text('暂停当前账号'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('值守中'), findsNothing);
        expect(container.read(accountMonitorProvider(null)).running, isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
