import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/app/adaptive_shell.dart';
import 'package:xmu_rollcall/core/network/tron_http_client.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_providers.dart';

class _TestAuthController extends AuthController {
  _TestAuthController()
      : super(
          AuthRepository(
            http: TronHttpClient(store: SecureStore()),
            store: SecureStore(),
          ),
        );

  @override
  Future<void> bootstrap() async {
    state = const AuthState(status: AuthStatus.signedOut);
  }
}

class _EmptyRollcalls extends ActiveRollcallsNotifier {
  @override
  Future<List<RollcallItem>> build() async => const [];
}

void main() {
  testWidgets('AdaptiveShell shows bottom nav on narrow width', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((ref) => _TestAuthController()),
          activeRollcallsProvider.overrideWith(_EmptyRollcalls.new),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const AdaptiveShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('签到'), findsWidgets);
    expect(find.text('监控'), findsWidgets);
  });

  testWidgets('AdaptiveShell shows rail on wide width', (tester) async {
    tester.view.physicalSize = const Size(1100, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((ref) => _TestAuthController()),
          activeRollcallsProvider.overrideWith(_EmptyRollcalls.new),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const AdaptiveShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('xmu-rollcall'), findsOneWidget);
  });
}
