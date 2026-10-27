import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/providers.dart';
import 'package:xmu_rollcall/features/schedule/academic_client.dart';

final academicRevisionProvider = StateProvider<int>((ref) => 0);
final academicSyncProvider = Provider<AcademicSync>((ref) {
  final sync = AcademicSync(
    ref.watch(secureStoreProvider),
    periodic: true,
    onUpdated: (_) {
      ref.read(academicRevisionProvider.notifier).state++;
    },
  );
  ref.onDispose(sync.dispose);
  return sync;
});
