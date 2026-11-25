import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/features/browser/browser_session.dart';
import 'campus_card_providers.dart';

/// Owns the current-account lifetime of native card operations, not their skin.
mixin CampusCardPageSession<T extends ConsumerStatefulWidget>
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
    ref.watch(campusCardInfoProvider);
    ref.listen(browserIdentityProvider, (_, next) {
      if (next == identity) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final route = ModalRoute.of(context);
        if (route != null && route.isActive) {
          Navigator.of(context).removeRoute(route);
        }
      });
    });
  }

  Future<void> perform(Future<void> Function() action) async {
    if (busy || !current) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
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
