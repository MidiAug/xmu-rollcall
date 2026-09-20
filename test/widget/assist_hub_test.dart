import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/app/providers.dart';
import 'package:xmu_rollcall/core/identity/device_identity.dart';
import 'package:xmu_rollcall/core/network/tron_http_client.dart';
import 'package:xmu_rollcall/core/session/assist_identity.dart';
import 'package:xmu_rollcall/core/session/assist_service.dart';
import 'package:xmu_rollcall/core/session/session_client_registry.dart';
import 'package:xmu_rollcall/core/session/session_credential.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/assist/assist_controller.dart';
import 'package:xmu_rollcall/features/assist/assist_dialogs.dart';
import 'package:xmu_rollcall/features/assist/assist_rollcall_hub_page.dart';
import 'package:xmu_rollcall/features/rollcall/qr_answer_page.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_providers.dart';

class _EmptyRollcalls extends ActiveRollcallsNotifier {
  @override
  Future<List<RollcallItem>> build(int? assistUserId) async => const [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('assist roster row opens hub with display name', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final memory = SecureStore.memory();
    const identity = AssistIdentity(
      userId: 42,
      displayName: '同学甲',
      kind: AssistCredentialKind.session,
      deviceId: 'dev-a',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secureStoreProvider.overrideWithValue(memory),
          deviceIdentityProvider.overrideWith((ref) => DeviceIdentity(memory)),
          sessionClientRegistryProvider.overrideWith(
            (ref) => SessionClientRegistry(
              store: memory,
              createClient: ({
                required store,
                required sessionKey,
                required rateLimiter,
              }) {
                return TronHttpClient(
                  store: store,
                  sessionKey: sessionKey,
                  rateLimiter: rateLimiter,
                  cookieJar: CookieJar(),
                );
              },
            ),
          ),
          assistServiceProvider.overrideWith((ref) async {
            final prefs = await SharedPreferences.getInstance();
            return AssistService(
              store: memory,
              registry: ref.watch(sessionClientRegistryProvider),
              prefs: prefs,
              probeProfile: (_) async =>
                  const AssistProfileSnapshot(id: 42, name: '同学甲'),
            );
          }),
          assistControllerProvider.overrideWith(
            (ref) => AssistController(
              ref,
              initial: const AssistUiState(
                enabled: true,
                ready: true,
                identities: [identity],
              ),
              bootstrap: false,
            ),
          ),
          activeRollcallsProvider.overrideWith(_EmptyRollcalls.new),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const AssistIdentitiesPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('同学甲'), findsOneWidget);
    await tester.tap(find.text('同学甲'));
    await tester.pump(); // start route
    await tester.pump(const Duration(milliseconds: 500)); // nav + bootstrap

    expect(find.byType(AssistRollcallHubPage), findsOneWidget);
    expect(find.text('开始检测'), findsOneWidget);
  });

  testWidgets('QR with enableAssistMulti false hides 提交对象', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final item = RollcallItem.fromJson({
      'rollcall_id': 1,
      'course_title': '测试课',
      'created_by_name': '老师',
      'is_qrcode': true,
      'status': 'on_call',
      'rollcall_status': 'start',
      'is_expired': false,
      'scored': false,
      'course_id': '9',
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assistControllerProvider.overrideWith(
            (ref) => AssistController(
              ref,
              initial: const AssistUiState(enabled: true, ready: true),
              bootstrap: false,
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: QrAnswerPage(
            item: item,
            assistUserId: 42,
            enableAssistMulti: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('提交对象'), findsNothing);
    expect(find.text('我（主号）'), findsNothing);
    expect(find.textContaining('该协助身份'), findsOneWidget);
  });
}
