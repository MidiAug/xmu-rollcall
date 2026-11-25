import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/features/browser/browser_session.dart';
import 'classroom_providers.dart';

mixin ClassroomPageSession<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  late final BrowserIdentity identity;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    identity = ref.read(browserIdentityProvider);
  }

  bool get current => mounted && ref.read(browserIdentityProvider) == identity;
  void watchSession() {
    ref.watch(classroomProvider);
    ref.listen(browserIdentityProvider, (_, next) {
      if (next == identity) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final r = ModalRoute.of(context);
        if (r != null && r.isActive) Navigator.of(context).removeRoute(r);
      });
    });
  }

  Future<void> perform(Future<void> Function() call) async {
    if (busy || !current) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await call();
    } catch (e) {
      if (current) {
        setState(
          () => error = e is FormatException ? e.message : '操作未完成，请检查网络后重试',
        );
      }
    } finally {
      if (current) setState(() => busy = false);
    }
  }
}
