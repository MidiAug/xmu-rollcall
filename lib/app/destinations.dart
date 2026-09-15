enum AppDestination {
  rollcall,
  history,
  settings,
}

extension AppDestinationX on AppDestination {
  String get label => switch (this) {
        AppDestination.rollcall => '签到',
        AppDestination.history => '记录',
        AppDestination.settings => '我的',
      };

  String get title => switch (this) {
        AppDestination.rollcall => '签到',
        AppDestination.history => '记录',
        AppDestination.settings => '我的',
      };
}
