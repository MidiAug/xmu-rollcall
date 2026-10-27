import 'package:flutter/widgets.dart';
import 'package:xmu_rollcall/app/destinations.dart';

class ShellTabDestination extends InheritedWidget {
  const ShellTabDestination({
    super.key,
    required this.destination,
    required super.child,
  });
  final AppDestination destination;
  static AppDestination? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ShellTabDestination>()
      ?.destination;
  @override
  bool updateShouldNotify(ShellTabDestination oldWidget) =>
      destination != oldWidget.destination;
}
