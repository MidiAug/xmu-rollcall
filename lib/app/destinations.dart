import 'package:xmu_rollcall/core/theme/app_icons.dart';
import 'package:flutter/material.dart';

/// Stable identities; UI order never depends on enum indices.
enum AppDestination { rollcall, homework, settings, timetable, campusTools }

const mobileDestinations = [
  AppDestination.rollcall,
  AppDestination.homework,
  AppDestination.settings,
];
const desktopDestinations = [
  AppDestination.rollcall,
  AppDestination.homework,
  AppDestination.timetable,
  AppDestination.campusTools,
  AppDestination.settings,
];

extension AppDestinationX on AppDestination {
  String get id => name;
  String get label => switch (this) {
    AppDestination.rollcall => '签到',
    AppDestination.homework => '作业',
    AppDestination.settings => '我的',
    AppDestination.timetable => '课表',
    AppDestination.campusTools => '校园工具',
  };
  String get desktopLabel => this == AppDestination.settings ? '设置' : label;
  String get title => label;
  IconData get icon => switch (this) {
    AppDestination.rollcall => AppIcons.rollcall,
    AppDestination.homework => AppIcons.homework,
    AppDestination.timetable => AppIcons.calendar,
    AppDestination.campusTools => AppIcons.tools,
    AppDestination.settings => AppIcons.settings,
  };
  IconData get selectedIcon => switch (this) {
    AppDestination.rollcall => AppIcons.rollcallSelected,
    AppDestination.homework => AppIcons.homeworkSelected,
    AppDestination.timetable => AppIcons.calendarSelected,
    AppDestination.campusTools => AppIcons.toolsSelected,
    AppDestination.settings => AppIcons.settingsSelected,
  };
}
