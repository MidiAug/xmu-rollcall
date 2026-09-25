import 'package:xmu_rollcall/app/destinations.dart';

/// Bridge so platform shell (tray / notify) can drive [AdaptiveShell] tabs.
class ShellNavigation {
  ShellNavigation._();

  static final ShellNavigation instance = ShellNavigation._();

  void Function(AppDestination destination, {bool popToRoot})? _select;

  void bind(
    void Function(AppDestination destination, {bool popToRoot}) select,
  ) {
    _select = select;
  }

  void unbind(
    void Function(AppDestination destination, {bool popToRoot}) select,
  ) {
    if (identical(_select, select)) _select = null;
  }

  /// Show the rollcall hub list (pop nested routes).
  void openRollcall({bool popToRoot = true}) {
    _select?.call(AppDestination.rollcall, popToRoot: popToRoot);
  }
}
