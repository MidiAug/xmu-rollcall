import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/providers.dart';
import 'package:xmu_rollcall/core/session/session_key.dart';
import 'package:xmu_rollcall/features/assist/assist_controller.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_repository.dart';

/// [assistUserId] null = owner session; otherwise assist jar + roster deviceId.
final rollcallRepositoryForProvider =
    Provider.family<RollcallRepository, int?>((ref, assistUserId) {
  final registry = ref.watch(sessionClientRegistryProvider);
  final key = assistUserId == null
      ? SessionKey.owner
      : SessionKey.assist(assistUserId);
  String? deviceOverride;
  if (assistUserId != null) {
    for (final e in ref.watch(assistControllerProvider).identities) {
      if (e.userId == assistUserId) {
        deviceOverride = e.deviceId;
        break;
      }
    }
  }
  return RollcallRepository(
    http: registry.forKey(key),
    identity: ref.watch(deviceIdentityProvider),
    deviceIdOverride: deviceOverride,
    requireExplicitDeviceId: assistUserId != null,
  );
});

final rollcallRepositoryProvider = Provider<RollcallRepository>((ref) {
  return ref.watch(rollcallRepositoryForProvider(null));
});
