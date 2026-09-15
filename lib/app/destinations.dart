enum AppDestination {
  rollcall,
  monitor,
  history,
  settings,
}

extension AppDestinationX on AppDestination {
  String get label => switch (this) {
        AppDestination.rollcall => '签到',
        AppDestination.monitor => '监控',
        AppDestination.history => '记录',
        AppDestination.settings => '我的',
      };

  String get title => switch (this) {
        AppDestination.rollcall => '进行中签到',
        AppDestination.monitor => '监控',
        AppDestination.history => '本机记录',
        AppDestination.settings => '我的',
      };
}
