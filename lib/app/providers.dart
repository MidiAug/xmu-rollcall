import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/identity/device_identity.dart';
import 'package:xmu_rollcall/core/network/tron_http_client.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';

final secureStoreProvider = Provider<SecureStore>((ref) => SecureStore());

final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) {
  return SharedPreferences.getInstance();
});

final deviceIdentityProvider = Provider<DeviceIdentity>((ref) {
  return DeviceIdentity(ref.watch(secureStoreProvider));
});

final tronHttpClientProvider = Provider<TronHttpClient>((ref) {
  return TronHttpClient(store: ref.watch(secureStoreProvider));
});

final appBootstrapProvider = FutureProvider<void>((ref) async {
  final client = ref.read(tronHttpClientProvider);
  await client.init();
  await ref.read(deviceIdentityProvider).getId();
});
