import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account.dart';
import 'detection_window.dart';
import 'detection_window_store.dart';

final detectionWindowProvider =
    StateNotifierProvider<DetectionWindowController, DetectionWindow?>((ref) {
      final owner = ref.watch(authControllerProvider).profile?.id;
      return DetectionWindowController(
        userId: ref.watch(selectedRollcallAccountProvider) ?? owner,
        ownerId: owner,
      );
    });

class DetectionWindowController extends StateNotifier<DetectionWindow?> {
  DetectionWindowController({this.userId, this.ownerId}) : super(null) {
    ready = _load();
  }
  final int? userId, ownerId;
  late final Future<void> ready;
  Future<void> _load() async {
    final window = await DetectionWindowStore.read(
      uid: userId,
      ownerId: ownerId,
    );
    if (mounted) state = window;
  }

  Future<void> save(DetectionWindow window) async {
    await DetectionWindowStore.save(window, userId: userId);
    if (mounted) state = window;
  }
}
