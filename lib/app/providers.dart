import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/identity/device_identity.dart';
import 'package:xmu_rollcall/core/network/tron_http_client.dart';
import 'package:xmu_rollcall/core/session/session_client_registry.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';
import 'package:xmu_rollcall/core/logging/app_log.dart';

final secureStoreProvider = Provider<SecureStore>((ref) => SecureStore());

final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) {
  return SharedPreferences.getInstance();
});

final deviceIdentityProvider = Provider<DeviceIdentity>((ref) {
  return DeviceIdentity(ref.watch(secureStoreProvider));
});

final sessionClientRegistryProvider = Provider<SessionClientRegistry>((ref) {
  return SessionClientRegistry(store: ref.watch(secureStoreProvider));
});

/// Owner (primary) TronClass HTTP client — discovery / login always use this.
final tronHttpClientProvider = Provider<TronHttpClient>((ref) {
  return ref.watch(sessionClientRegistryProvider).owner();
});

final appBootstrapProvider = FutureProvider<void>((ref) async {
  final client = ref.read(tronHttpClientProvider);
  final watch = Stopwatch()..start();
  await Future.wait([client.init(), ref.read(deviceIdentityProvider).getId()]);
  AppLog.event(
    'app.bootstrap.ready',
    fields: {'elapsedMs': watch.elapsedMilliseconds},
  );
});
