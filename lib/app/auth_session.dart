import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/providers.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/monitor/monitor_controller.dart';
import 'package:xmu_rollcall/features/schedule/academic_providers.dart';

AuthController createAppAuthController(Ref ref) {
  late final AuthController controller;
  controller = AuthController(
    ref.watch(authRepositoryProvider),
    afterRestore: (profile) => ref.read(academicSyncProvider).sync(profile.id),
    afterSignIn: (profile, username, password) async {
      await ref
          .read(academicSyncProvider)
          .sync(
            profile.id,
            sso: ref.read(tronHttpClientProvider).cookieJar,
            username: username,
            password: password,
            force: true,
          );
      if (controller.isSignedInAs(profile.id)) {
        ref.read(academicRevisionProvider.notifier).state++;
      }
    },
    beforeSignOut: () => ref
        .read(monitorControllerProvider.notifier)
        .stopAsync(reason: 'sign_out'),
  );
  return controller;
}
