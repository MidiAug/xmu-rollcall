enum AppDestination {
  rollcall,
  homework,
  settings,
}

extension AppDestinationX on AppDestination {
  String get label => switch (this) {
        AppDestination.rollcall => '签到',
        AppDestination.homework => '作业',
        AppDestination.settings => '我的',
      };

  String get title => switch (this) {
        AppDestination.rollcall => '签到',
        AppDestination.homework => '作业',
        AppDestination.settings => '我的',
      };
}
