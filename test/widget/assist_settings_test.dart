import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:xmu_rollcall/app/providers.dart';
import 'package:xmu_rollcall/core/identity/device_identity.dart';
import 'package:xmu_rollcall/core/network/tron_http_client.dart';
import 'package:xmu_rollcall/core/session/session_client_registry.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/assist/assist_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';
import 'package:xmu_rollcall/features/settings/settings_page.dart';

class _TestAuthController extends AuthController {
  _TestAuthController()
      : super(
          AuthRepository(
            http: TronHttpClient(store: SecureStore.memory()),
            store: SecureStore.memory(),
          ),
        );

  @override
  Future<void> bootstrap() async {
    state = const AuthState(status: AuthStatus.signedOut);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('assist section shows import export without master switch', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final memory = SecureStore.memory();

    // Tall surface so ListView builds sections below the fold (课程与缓存).
    await tester.binding.setSurfaceSize(const Size(400, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
          authControllerProvider.overrideWith((ref) => _TestAuthController()),
          assistControllerProvider.overrideWith(
            (ref) => AssistController(
              ref,
              initial: const AssistUiState(ready: true),
              bootstrap: false,
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const SettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('协助签到'), findsOneWidget);
    expect(find.text('启用协助'), findsNothing);
    expect(find.text('导出协助码'), findsOneWidget);
    expect(find.text('导入协助身份'), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
  });
}
