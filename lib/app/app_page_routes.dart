import 'package:flutter/material.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';

/// Shared-axis–lite subpage routes (slide + fade). Desktop and mobile share one curve.
abstract final class AppPageRoutes {
  static const _slideFraction = 0.08;

  static Future<T?> push<T extends Object?>(BuildContext context, Widget page) {
    AppShellSelect.closeAll();
    return Navigator.of(context).push<T>(build<T>(page));
  }

  static Route<T> build<T extends Object?>(Widget page) {
    return PageRouteBuilder<T>(
      transitionDuration: AppMotion.page,
      reverseTransitionDuration: AppMotion.page,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: AppMotion.pageCurve,
          reverseCurve: Curves.easeInCubic,
        );
        final offset = Tween<Offset>(
          begin: const Offset(_slideFraction, 0),
          end: Offset.zero,
        ).animate(curved);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(position: offset, child: child),
        );
      },
    );
  }
}
